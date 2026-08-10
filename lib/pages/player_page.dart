import 'dart:async';

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
      setState(() {
        _error = e.isEmpty ? null : e;
        _buffering = false;
      });
    });
    _player.stream.playing.listen((p) {
      if (!mounted) return;
      if (p) setState(() => _error = null);
    });
  }

  void _openChannel(int index, {bool first = false}) async {
    if (index < 0 || index >= widget.channels.length) return;
    setState(() {
      _index = index;
      _buffering = true;
      _error = null;
    });
    final channel = widget.channels[index];
    await _player.open(Media(channel.url));
    if (!mounted) return;

    final state = AppScope.of(context);
    await state.addRecent(channel);
    if (state.keepScreenOn) await WakelockPlus.enable();

    _loadEpg(channel);
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
              maxLines: 3,
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
