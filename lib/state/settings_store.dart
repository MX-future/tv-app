import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../models/play_source.dart';

/// 本地持久化（收藏 / 最近播放 / 自定义源 / 设置）。
class SettingsStore {
  SettingsStore._(this._prefs);

  final SharedPreferences _prefs;

  static const _kCustomSources = 'custom_sources';
  static const _kFavorites = 'favorites';
  static const _kRecent = 'recent';
  static const _kLastSourceId = 'last_source_id';
  static const _kKeepScreenOn = 'keep_screen_on';

  static Future<SettingsStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsStore._(prefs);
  }

  // ---------- 自定义源 ----------

  List<PlaySource> get customSources {
    final raw = _prefs.getStringList(_kCustomSources) ?? const [];
    return raw
        .map((s) => PlaySource.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> setCustomSources(List<PlaySource> sources) async {
    await _prefs.setStringList(
      _kCustomSources,
      sources.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  // ---------- 收藏 ----------

  List<String> get favorites => _prefs.getStringList(_kFavorites) ?? const [];

  Future<void> setFavorites(List<String> ids) async {
    await _prefs.setStringList(_kFavorites, ids);
  }

  // ---------- 最近播放 ----------

  List<Channel> get recent {
    final raw = _prefs.getStringList(_kRecent) ?? const [];
    return raw
        .map((s) => Channel.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> setRecent(List<Channel> channels) async {
    await _prefs.setStringList(
      _kRecent,
      channels.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  // ---------- 其他 ----------

  String? get lastSourceId => _prefs.getString(_kLastSourceId);

  Future<void> setLastSourceId(String id) async {
    await _prefs.setString(_kLastSourceId, id);
  }

  bool get keepScreenOn => _prefs.getBool(_kKeepScreenOn) ?? true;

  Future<void> setKeepScreenOn(bool value) async {
    await _prefs.setBool(_kKeepScreenOn, value);
  }
}
