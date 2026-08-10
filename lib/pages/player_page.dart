import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app.dart';
import '../models/channel.dart';
import '../models/epg_program.dart';

/// 全屏直播播放页。
class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.channels,
    required this.initialIndex,
  });

  final List<Channel> channels;
  final int initialIndex;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late VideoController _controller;
  late int _index;

  bool _buffering = true;
  String? _error;
  bool _showOverlay = true;
  List<EpgProgram> _epg = const [];
  Timer? _overlayTimer;

  // 候选播放地址（主地址 + 跨源备用）
  List<String> _candidates = [];
  int _candidateIndex = 0;
  String? _altNote; // "备用源 2/3…"
  Timer? _errorDebounce;

  /// 本次播放会话内是否已确认"移动数据继续播放"
  bool _trafficConfirmed = false;

  /// 当前流是否已成功播放过（用于区分瞬时错误与真实失败）
  bool _hasPlayed = false;

  /// 已播放状态下收到错误后的观察计时器（等待播放器自动恢复）
  Timer? _recoverTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _initOrientation();
    _player = Player();
    _controller = VideoController(_player);
    _listenPlayer();
    _openChannel(_index, first: true);
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _errorDebounce?.cancel();
    _recoverTimer?.cancel();
    _player.dispose();
    WakelockPlus.disable();
    _restoreOrientation();
    super.dispose();
  }

  // ---------- 系统 UI ----------

  void _initOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restoreOrientation() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ---------- 播放 ----------

  void _listenPlayer() {
    _player.stream.buffering.listen((b) {
      if (!mounted) return;
      setState(() => _buffering = b);
    });
    _player.stream.error.listen((e) {
      if (!mounted) return;
      _onStreamError(e.isEmpty ? '播放失败' : e);
    });
    _player.stream.playing.listen((p) {
      if (!mounted) return;
      if (p) {
        // 成功播放：清除错误状态与观察计时器
        _hasPlayed = true;
        _recoverTimer?.cancel();
        _recoverTimer = null;
        setState(() {
          _error = null;
          _altNote = null;
          _buffering = false;
        });
      }
    });
  }

  /// 统一错误入口：区分瞬时错误（播放中分片失败，可自动恢复）与真实失败。
  void _onStreamError(String raw) {
    if (_hasPlayed) {
      // 已成功播放过：先观察，等待播放器自动恢复；超过时限仍未恢复才判失败
      _recoverTimer?.cancel();
      _recoverTimer = Timer(const Duration(seconds: 4), () {
        _recoverTimer = null;
        if (!mounted) return;
        if (_player.state.playing) return; // 已恢复，忽略
        _onPlayError(raw); // 确实中断，按失败处理
      });
      return;
    }
    // 尚未播放成功：直接按失败处理（尝试候选/报错）
    _onPlayError(raw);
  }

  /// 打开指定索引的频道（构建候选地址列表）。
  Future<void> _openChannel(int index, {bool first = false}) async {
    if (index < 0 || index >= widget.channels.length) return;
    final state = AppScope.of(context);

    // 流量提醒：开启"仅 WiFi 下播放"且当前为移动网络时，首次需确认
    if (!_trafficConfirmed && state.wifiOnly) {
      final isMobile = await _isMobileNetwork();
      if (!mounted) return;
      if (isMobile) {
        final ok = await _showTrafficConfirm();
        if (!mounted) return;
        if (ok != true) {
          // 用户取消：立即停止播放并退出播放页，避免流量继续消耗
          await _player.stop();
          if (mounted) Navigator.of(context).maybePop();
          return;
        }
        _trafficConfirmed = true;
      }
    }
    if (!mounted) return;

    final channel = widget.channels[index];
    setState(() {
      _index = index;
      _buffering = true;
      _error = null;
      _altNote = null;
    });
    _hasPlayed = false;
    _recoverTimer?.cancel();
    _recoverTimer = null;
    _candidates = state.candidateUrls(channel);
    _candidateIndex = 0;
    await _openUrl(_candidates.first);

    await state.addRecent(channel);
    if (state.keepScreenOn) await WakelockPlus.enable();
    _loadEpg(channel);
  }

  /// 检测当前是否为移动数据网络（检测失败时不拦截）。
  Future<bool> _isMobileNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r == ConnectivityResult.mobile);
    } catch (_) {
      return false;
    }
  }

  Future<bool?> _showTrafficConfirm() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, size: 22, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text('当前为移动数据', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: const Text(
          '当前使用移动数据流量播放直播，会消耗手机流量。\n是否继续播放？',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('继续播放'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    await _player.open(Media(url));
  }

  /// 播放失败：自动尝试下一个候选地址，全部失败才显示错误。
  void _onPlayError(String raw) {
    if (_errorDebounce?.isActive ?? false) return;
    _errorDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (_candidateIndex < _candidates.length - 1) {
        _candidateIndex++;
        _hasPlayed = false;
        _recoverTimer?.cancel();
        _recoverTimer = null;
        setState(() {
          _buffering = true;
          _altNote = _candidates.length > 1
              ? '备用源 ${_candidateIndex + 1}/${_candidates.length}，正在尝试…'
              : null;
        });
        _openUrl(_candidates[_candidateIndex]);
      } else {
        setState(() {
          _buffering = false;
          _error = _friendlyError(raw, _candidates.last);
        });
      }
    });
  }

  /// 把底层错误转成用户可读的提示。
  String _friendlyError(String raw, String url) {
    final base = raw.trim();
    if (url.contains('[') || url.contains(']:')) {
      return '$base\n\n该频道为 IPv6 直播源，当前网络可能不支持 IPv6，请切换其它频道或直播源。';
    }
    if (base.contains('HTTP 403') || base.contains('403')) {
      return '$base\n该源可能已失效或禁止访问。';
    }
    return base;
  }

  void _retry() {
    _openChannel(_index);
  }

  void _switchBy(int delta) {
    _openChannel((_index + delta + widget.channels.length) % widget.channels.length);
    _flashOverlay();
  }

  // ---------- EPG ----------

  Future<void> _loadEpg(Channel channel) async {
    final state = AppScope.of(context);
    final programs = await state.loadEpgForChannel(channel);
    if (!mounted || widget.channels[_index].id != channel.id) return;
    setState(() => _epg = programs);
  }

  // ---------- 覆盖层 ----------

  void _flashOverlay() {
    _overlayTimer?.cancel();
    setState(() => _showOverlay = true);
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
    if (_showOverlay) _flashOverlay();
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final channel = widget.channels[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleOverlay,
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v.abs() < 200) return;
          _switchBy(v > 0 ? -1 : 1);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 播放画面
            Video(controller: _controller, controls: NoVideoControls),
            // 缓冲指示
            if (_buffering && _error == null)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    SizedBox(height: 12),
                    Text('加载中…', style: TextStyle(fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
            // 播放失败
            if (_error != null) _buildErrorOverlay(channel),
            // 顶部 / 底部覆盖层
            if (_showOverlay) ...[
              _buildTopBar(channel),
              _buildBottomBar(channel),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Channel channel) {
    final state = AppScope.of(context);
    final fav = state.isFavorite(channel);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          left: 4,
          right: 4,
          bottom: 16,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${channel.group} · ${_index + 1}/${widget.channels.length}',
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  if (_altNote != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _altNote!,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFFFFC107)),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: fav ? '取消收藏' : '收藏',
              icon: Icon(
                fav ? Icons.star : Icons.star_border,
                color: fav ? const Color(0xFFFFC107) : Colors.white,
              ),
              onPressed: () => state.toggleFavorite(channel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(Channel channel) {
    final current = _epg.where((p) => p.isNow).firstOrNull;
    final upcoming = _epg.where((p) => p.start.isAfter(DateTime.now())).firstOrNull;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current != null)
              _epgRow(
                icon: Icons.play_circle_outline,
                color: const Color(0xFF4CAF50),
                text: '正在播出  ${_fmtTime(current.start)} - ${_fmtTime(current.end)}  ${current.title}',
              ),
            if (upcoming != null)
              _epgRow(
                icon: Icons.schedule,
                color: Colors.white54,
                text: '接下来    ${_fmtTime(upcoming.start)}  ${upcoming.title}',
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.swipe, size: 14, color: Colors.white30),
                const SizedBox(width: 6),
                Text(
                  '左右滑动换台 · 点击屏幕隐藏菜单',
                  style: TextStyle(fontSize: 11.5, color: Colors.white30),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _epgRow({required IconData icon, required Color color, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay(Channel channel) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              '播放失败',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重试'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _switchBy(1),
                  child: const Text('下一个频道'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }
}
