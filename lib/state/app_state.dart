import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/default_sources.dart';
import '../models/channel.dart';
import '../models/epg_program.dart';
import '../models/play_source.dart';
import '../services/epg_parser.dart';
import '../services/playlist_parser.dart';
import '../services/stream_loader.dart';
import 'settings_store.dart';

/// 应用全局状态。
class AppState extends ChangeNotifier {
  AppState();

  late SettingsStore _store;

  /// 数据获取函数（默认走网络，测试时可注入假数据）。
  Future<String> Function(String url) fetchText = StreamLoader.fetchText;

  /// 内置离线快照读取函数（由 main 注入 rootBundle.loadString）。
  /// 未注入时离线兜底不生效，不影响其他功能。
  Future<String?> Function(String assetPath)? assetLoader;

  // ---------- 源与频道 ----------

  /// 全部可用源（内置 + 自定义）
  List<PlaySource> sources = [];

  /// 当前激活的源
  PlaySource? activeSource;

  /// 当前源解析出的频道列表
  List<Channel> channels = [];

  /// 分组列表（保持源文件出现顺序，"未分组"置后）
  List<String> groups = [];

  bool loading = false;
  String? loadError;

  /// 自动切换源的提示（如"原源不可用，已自动切换…"）
  String? fallbackNote;

  /// 当前源使用的 EPG 地址
  String? epgUrl;

  // ---------- 收藏与最近 ----------

  final Set<String> _favorites = {};
  List<Channel> recent = [];

  // ---------- EPG ----------

  final Map<String, List<EpgProgram>> _epgCache = {};
  bool epgLoading = false;

  /// 跨源频道播放地址池：normalizedKey -> 候选 URL 列表（新源优先）
  final Map<String, List<String>> _channelUrlPool = {};

  /// 收集当前源频道到播放地址池，并回填 altUrls。
  void _mergeChannelPool(List<Channel> loaded) {
    for (final c in loaded) {
      final key = c.normalizedKey;
      final list = _channelUrlPool.putIfAbsent(key, () => []);
      for (final u in [c.url, ...c.altUrls]) {
        list.removeWhere((x) => x == u);
        list.insert(0, u);
      }
      if (list.length > 8) list.removeRange(8, list.length);
    }
    for (var i = 0; i < channels.length; i++) {
      final c = channels[i];
      final pool = _channelUrlPool[c.normalizedKey] ?? const [];
      final alts = pool.where((u) => u != c.url).take(4).toList();
      if (alts.isNotEmpty && !listEquals(alts, c.altUrls)) {
        channels[i] = c.withAltUrls(alts);
      }
    }
  }

  /// 获取频道的全部候选播放地址（主地址 + 备用 + 池内历史）。
  List<String> candidateUrls(Channel channel) {
    final result = <String>[];
    for (final u in [channel.url, ...channel.altUrls]) {
      if (!result.contains(u)) result.add(u);
    }
    final pool = _channelUrlPool[channel.normalizedKey] ?? const [];
    for (final u in pool) {
      if (!result.contains(u)) result.add(u);
    }
    return result;
  }

  // ---------- 设置 ----------

  bool keepScreenOn = true;

  /// 仅 WiFi 下播放（移动数据时弹窗提醒）
  bool wifiOnly = false;

  // ---------- 初始化 ----------

  Future<void> init() async {
    _store = await SettingsStore.create();
    sources = [..._store.customSources, ...kDefaultSources];
    _favorites.addAll(_store.favorites);
    recent = _store.recent;
    keepScreenOn = _store.keepScreenOn;
    wifiOnly = _store.wifiOnly;
    // 立即刷新 UI：源条立即可见，不依赖网络请求完成
    notifyListeners();

    // 恢复上次使用的源（内部自动轮询镜像/其他源）
    final lastId = _store.lastSourceId;
    final target =
        sources.where((s) => s.id == lastId).firstOrNull ?? sources.firstOrNull;
    if (target != null) {
      await loadChannels(target);
      // 后台静默预加载其他内置源，充实跨源候选池
      unawaited(preloadOtherSources());
    }
    notifyListeners();
  }

  /// 后台静默加载其他内置源，仅合并到候选池（不切换当前频道列表）。
  Future<void> preloadOtherSources() async {
    final current = activeSource ?? sources.firstOrNull;
    if (current == null) return;
    final others = _fallbackSources(current);
    for (final s in others.take(2)) {
      try {
        final r = await _fetchFirst(s.candidates.take(2).toList());
        final parsed = PlaylistParser.parse(r.text, sourceName: s.name);
        if (parsed.channels.isNotEmpty) {
          _mergeChannelPool(parsed.channels);
        }
      } catch (_) {
        // 静默失败，不影响主流程
      }
    }
    notifyListeners();
  }

  // ---------- 频道加载 ----------

  /// 加载指定源的频道列表。
  ///
  /// 策略（逐级降级，保证不出现"加载失败"）：
  /// 1. 当前源的全部通道**并发竞速**（主地址与镜像同时请求，最快者胜出）
  /// 2. 换其他内置源的首选通道再试
  /// 3. 全部网络通道不可用 → App 内置离线快照
  ///
  /// 加载期间 [loading] 为 true，用于 UI 反馈。
  Future<void> loadChannels(PlaySource source) async {
    loading = true;
    loadError = null;
    fallbackNote = null;
    notifyListeners();

    String? lastError;
    String? usedUrl;
    List<Channel>? loaded;

    // 1) 当前源全部通道并发竞速
    try {
      final r = await _fetchFirst(source.candidates);
      final parsed = PlaylistParser.parse(r.text, sourceName: source.name);
      if (parsed.channels.isEmpty) throw Exception('播放列表为空');
      loaded = parsed.channels;
      usedUrl = r.url;
      epgUrl = parsed.epgUrl;
    } catch (e) {
      lastError = e.toString();

      // 2) 其他内置源再试（每个源取其前两个通道并发）
      for (final s in _fallbackSources(source).take(3)) {
        try {
          final r = await _fetchFirst(s.candidates.take(2).toList());
          final parsed = PlaylistParser.parse(r.text, sourceName: source.name);
          if (parsed.channels.isEmpty) continue;
          loaded = parsed.channels;
          usedUrl = r.url;
          epgUrl = parsed.epgUrl;
          lastError = null;
          break;
        } catch (e2) {
          lastError = e2.toString();
        }
      }
    }

    if (loaded != null) {
      // 同源多地址合并（一个频道保留一个条目，其余作为备用）
      channels = PlaylistParser.mergeDuplicateChannels(loaded);
      activeSource = source;
      _mergeChannelPool(channels);
      _rebuildGroups();
      await _store.setLastSourceId(source.id);
      if (usedUrl != null && usedUrl != source.url) {
        // 并发竞速下镜像可能先返回，用中性文案避免"主地址坏了"的误报
        fallbackNote = '已通过加速通道加载频道列表';
      }
    } else {
      // 3) 全部网络通道失败 → App 内置离线快照
      final offline = await _loadOfflineChannels(source);
      if (offline != null) {
        channels = PlaylistParser.mergeDuplicateChannels(offline);
        activeSource = source;
        epgUrl = null;
        _mergeChannelPool(channels);
        _rebuildGroups();
        fallbackNote = '网络源暂时无法访问，已使用 App 内置频道表，可下拉重试';
      } else {
        loadError = lastError;
      }
    }
    loading = false;
    notifyListeners();
  }

  /// 并发请求多个地址，返回**最先成功**的那个 (url, text)。
  ///
  /// 相比串行重试，最坏等待时间等于单个超时，而不是 N 倍超时。
  Future<({String url, String text})> _fetchFirst(List<String> urls) {
    if (urls.isEmpty) {
      return Future.error(Exception('没有可用的源地址'));
    }
    final completer = Completer<({String url, String text})>();
    var pending = urls.length;
    final errors = <String>[];

    for (final url in urls) {
      fetchText(url).then(
        (text) {
          if (!completer.isCompleted) {
            completer.complete((url: url, text: text));
          }
        },
        onError: (Object e) {
          errors.add('$e');
          pending--;
          if (pending == 0 && !completer.isCompleted) {
            completer.completeError(
              Exception(errors.isEmpty ? '全部地址均不可用' : errors.first),
            );
          }
        },
      );
    }
    return completer.future;
  }

  /// 读取内置离线快照并解析；不可用时返回 null。
  Future<List<Channel>?> _loadOfflineChannels(PlaySource source) async {
    final loader = assetLoader;
    final path = source.assetPath;
    if (loader == null || path == null) return null;
    try {
      final text = await loader(path);
      if (text == null || text.trim().isEmpty) return null;
      final parsed = PlaylistParser.parse(text, sourceName: source.name);
      return parsed.channels.isEmpty ? null : parsed.channels;
    } catch (_) {
      return null;
    }
  }

  /// 其他可作为兜底的源（内置优先，排除 [source] 自身）。
  List<PlaySource> _fallbackSources(PlaySource source) {
    final rest = sources.where((s) => s.id != source.id).toList();
    rest.sort((a, b) => (a.builtIn ? 0 : 1) - (b.builtIn ? 0 : 1));
    return rest;
  }

  void _rebuildGroups() {
    final ordered = <String>[];
    for (final c in channels) {
      if (!ordered.contains(c.group)) ordered.add(c.group);
    }
    // 未分组置后
    ordered.sort((a, b) {
      if (a == '未分组' && b != '未分组') return 1;
      if (b == '未分组' && a != '未分组') return -1;
      return 0;
    });
    groups = ordered;
  }

  /// 按分组取频道。
  List<Channel> channelsOf(String group) =>
      channels.where((c) => c.group == group).toList();

  // ---------- 收藏 ----------

  bool isFavorite(Channel channel) => _favorites.contains(channel.id);

  Future<void> toggleFavorite(Channel channel) async {
    if (!_favorites.remove(channel.id)) {
      _favorites.add(channel.id);
    }
    await _store.setFavorites(_favorites.toList());
    notifyListeners();
  }

  // ---------- 最近播放 ----------

  Future<void> addRecent(Channel channel) async {
    recent.removeWhere((c) => c.id == channel.id);
    recent.insert(0, channel.withRecentAt(DateTime.now()));
    if (recent.length > 30) {
      recent = recent.sublist(0, 30);
    }
    await _store.setRecent(recent);
    notifyListeners();
  }

  Future<void> clearRecent() async {
    recent = [];
    await _store.setRecent(recent);
    notifyListeners();
  }

  /// 删除单条最近播放记录。
  Future<void> removeRecent(Channel channel) async {
    recent.removeWhere((c) => c.id == channel.id);
    await _store.setRecent(recent);
    notifyListeners();
  }

  // ---------- 自定义源管理 ----------

  Future<void> addCustomSource(String name, String url) async {
    final custom = sources
        .where((s) => !s.builtIn)
        .toList();
    custom.insert(
      0,
      PlaySource(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim().isEmpty ? url.split('/').last : name.trim(),
        url: url.trim(),
      ),
    );
    await _store.setCustomSources(custom);
    sources = [...custom, ...kDefaultSources];
    notifyListeners();
  }

  Future<void> removeSource(PlaySource source) async {
    if (source.builtIn) return;
    final custom = sources
        .where((s) => !s.builtIn && s.id != source.id)
        .toList();
    await _store.setCustomSources(custom);
    sources = [...custom, ...kDefaultSources];
    if (activeSource?.id == source.id) {
      activeSource = null;
      channels = [];
      groups = [];
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  // ---------- EPG ----------

  /// 加载某频道今天的节目单（缓存到内存）。
  Future<List<EpgProgram>> loadEpgForChannel(Channel channel) async {
    final key = channel.epgKey;
    final cached = _epgCache[key];
    if (cached != null) return cached;

    final url = epgUrl ?? PlaySource.defaultEpgUrl;
    epgLoading = true;
    notifyListeners();
    try {
      final bytes = await fetchText(url);
      final map = EpgParser.parse(bytes, channelName: channel.epgKey);
      final list = map.values.expand((e) => e).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      _epgCache[key] = list;
      return list;
    } catch (_) {
      return const [];
    } finally {
      epgLoading = false;
      notifyListeners();
    }
  }

  // ---------- 设置 ----------

  Future<void> setKeepScreenOn(bool value) async {
    keepScreenOn = value;
    await _store.setKeepScreenOn(value);
    notifyListeners();
  }

  Future<void> setWifiOnly(bool value) async {
    wifiOnly = value;
    await _store.setWifiOnly(value);
    notifyListeners();
  }

  // ---------- 工具 ----------

  /// 从频道列表按关键字搜索。
  static List<Channel> search(List<Channel> all, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((c) => c.name.toLowerCase().contains(q)).toList();
  }
}
