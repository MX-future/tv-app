import '../models/channel.dart';
import '../models/play_source.dart';

/// m3u / txt 播放列表解析结果。
class ParsedPlaylist {
  const ParsedPlaylist({required this.channels, this.epgUrl});

  final List<Channel> channels;

  /// 从 m3u 头部 x-tvg-url 提取的 EPG 地址（txt 源为空）
  final String? epgUrl;
}

/// m3u / txt 播放列表解析器。
class PlaylistParser {
  const PlaylistParser._();

  /// 解析播放列表内容，自动识别 m3u / txt 格式。
  static ParsedPlaylist parse(String content, {String? sourceName}) {
    final trimmed = content.trimLeft();
    if (trimmed.startsWith('#EXTM3U')) {
      return parseM3u(content, sourceName: sourceName);
    }
    return ParsedPlaylist(
      channels: parseTxt(content, sourceName: sourceName),
    );
  }

  /// 解析标准 m3u 播放列表。
  ///
  /// 格式示例：
  /// #EXTM3U x-tvg-url="https://live.fanmingming.cn/e.xml"
  /// #EXTINF:-1 tvg-name="CCTV1" tvg-logo="https://live.fanmingming.cn/tv/CCTV1.png" group-title="央视频道",CCTV-1综合
  /// http://example.com/playlist.m3u8
  static ParsedPlaylist parseM3u(String content, {String? sourceName}) {
    String? epgUrl;
    final channels = <Channel>[];
    final lines = content.split(RegExp(r'\r?\n'));

    String? pendingExtinf;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTM3U')) {
        final m = RegExp(r'x-tvg-url="([^"]+)"').firstMatch(line);
        if (m != null && m.group(1)!.trim().isNotEmpty) {
          epgUrl = m.group(1)!.trim();
        }
        continue;
      }

      if (line.startsWith('#EXTINF:')) {
        pendingExtinf = line;
        continue;
      }

      if (line.startsWith('#')) continue; // 其他注释行（如 #EXTVLCOPT）

      // 真正的 URL 行
      final url = line;
      if (pendingExtinf != null) {
        final channel = _parseExtinf(pendingExtinf, url, sourceName);
        if (channel != null) channels.add(channel);
        pendingExtinf = null;
      }
    }

    // 容错：若 EPG 未声明，回退默认接口
    epgUrl ??= PlaySource.defaultEpgUrl;
    return ParsedPlaylist(channels: channels, epgUrl: epgUrl);
  }

  /// 解析 txt 格式播放列表（"频道名,URL" 每行一条）。
  static List<Channel> parseTxt(String content, {String? sourceName}) {
    final channels = <Channel>[];
    for (final raw in content.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final idx = line.indexOf(',');
      if (idx <= 0) continue;
      final name = line.substring(0, idx).trim();
      final url = line.substring(idx + 1).trim();
      if (name.isEmpty || url.isEmpty) continue;
      if (!url.startsWith('http')) continue;
      channels.add(Channel(
        name: name,
        group: '未分组',
        url: url,
        sourceName: sourceName,
      ));
    }
    return channels;
  }

  static Channel? _parseExtinf(String extinf, String url, String? sourceName) {
    final tvgName = _attr(extinf, 'tvg-name');
    final logo = _attr(extinf, 'tvg-logo');
    final group = _attr(extinf, 'group-title');

    // 逗号之后为频道显示名
    final comma = extinf.indexOf(',');
    var name = comma >= 0 ? extinf.substring(comma + 1).trim() : '';
    if (name.isEmpty) name = tvgName ?? '未知频道';

    return Channel(
      name: name,
      group: (group == null || group.trim().isEmpty) ? '未分组' : group.trim(),
      url: url,
      tvgName: tvgName,
      logo: logo,
      sourceName: sourceName,
    );
  }

  static String? _attr(String line, String key) {
    final m = RegExp('$key="([^"]*)"').firstMatch(line);
    return m?.group(1);
  }
}
