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

  /// 当前源使用的 EPG 地址
  String? epgUrl;

  // ---------- 收藏与最近 ----------

  final Set<String> _favorites = {};
  List<Channel> recent = [];

  // ---------- EPG ----------

  final Map<String, List<EpgProgram>> _epgCache = {};
  bool epgLoading = false;

  // ---------- 设置 ----------

  bool keepScreenOn = true;

  // ---------- 初始化 ----------

  Future<void> init() async {
    _store = await SettingsStore.create();
    sources = [..._store.customSources, ...kDefaultSources];
    _favorites.addAll(_store.favorites);
    recent = _store.recent;
    keepScreenOn = _store.keepScreenOn;

    // 恢复上次使用的源
    final lastId = _store.lastSourceId;
    final target = sources.where((s) => s.id == lastId).firstOrNull ?? sources.firstOrNull;
    if (target != null) {
      await loadChannels(target, silent: true);
    }
    notifyListeners();
  }

  // ---------- 频道加载 ----------

  /// 加载指定源的频道列表。
  Future<void> loadChannels(PlaySource source, {bool silent = false}) async {
    if (!silent) {
      loading = true;
      loadError = null;
      notifyListeners();
    }
    try {
      final text = await StreamLoader.fetchText(source.url);
      final parsed = PlaylistParser.parse(text, sourceName: source.name);
      if (parsed.channels.isEmpty) {
        throw Exception('播放列表为空，请检查源地址');
      }
      channels = parsed.channels;
      activeSource = source;
      epgUrl = parsed.epgUrl;
      _rebuildGroups();
      await _store.setLastSourceId(source.id);
    } catch (e) {
      loadError = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
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

  // ---------- 工具 ----------

  /// 从频道列表按关键字搜索。
  static List<Channel> search(List<Channel> all, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((c) => c.name.toLowerCase().contains(q)).toList();
  }
}
