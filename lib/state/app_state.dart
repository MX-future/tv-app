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
        final text = await StreamLoader.fetchText(s.candidates.first);
        final parsed = PlaylistParser.parse(text, sourceName: s.name);
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
  /// 失败时自动按序尝试：该源镜像地址 → 其他可用源（内置优先）。
  /// 加载期间 [loading] 为 true，用于 UI 反馈。
  Future<void> loadChannels(PlaySource source) async {
    loading = true;
    loadError = null;
    fallbackNote = null;
    notifyListeners();

    // 1) 组装候选地址：目标源主地址+镜像 → 其他源（内置优先）
    final ordered = <String>[];
    void addCandidates(PlaySource s) {
      for (final u in s.candidates) {
        if (!ordered.contains(u)) ordered.add(u);
      }
    }

    addCandidates(source);
    for (final s in _fallbackSources(source)) {
      addCandidates(s);
    }

    // 2) 依次尝试
    String? lastError;
    String? usedUrl;
    for (final url in ordered) {
      try {
        final text = await StreamLoader.fetchText(url);
        final parsed = PlaylistParser.parse(text, sourceName: source.name);
        if (parsed.channels.isEmpty) {
          throw Exception('播放列表为空，请检查源地址');
        }
        // 同源多地址合并（一个频道保留一个条目，其余作为备用）
        channels = PlaylistParser.mergeDuplicateChannels(parsed.channels);
        activeSource = source;
        epgUrl = parsed.epgUrl;
        _mergeChannelPool(channels);
        _rebuildGroups();
        await _store.setLastSourceId(source.id);
        usedUrl = url;
        lastError = null;
        break;
      } catch (e) {
        lastError = e.toString();
      }
    }

    // 3) 结果与提示
    if (lastError != null) {
      loadError = lastError;
    } else if (usedUrl != null && usedUrl != source.url) {
      final usedName = _nameOfUrl(usedUrl) ?? source.name;
      fallbackNote = '「${source.name}」不可用，已自动使用 $usedName';
    }
    loading = false;
    notifyListeners();
  }

  /// 其他可作为兜底的源（内置优先，排除 [source] 自身）。
  List<PlaySource> _fallbackSources(PlaySource source) {
    final rest = sources.where((s) => s.id != source.id).toList();
    rest.sort((a, b) => (a.builtIn ? 0 : 1) - (b.builtIn ? 0 : 1));
    return rest;
  }

  /// 根据地址反查所属源名称。
  String? _nameOfUrl(String url) {
    for (final s in sources) {
      if (s.candidates.contains(url)) return s.name;
    }
    return null;
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
    recent.insert(0, channel);
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
      final bytes = await StreamLoader.fetchText(url);
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
