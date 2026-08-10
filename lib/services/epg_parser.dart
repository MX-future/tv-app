import '../models/epg_program.dart';

/// EPG XML（e.xml）解析器。
///
/// fanmingming/live 的 EPG 遵循 XMLTV 规范，格式示例：
/// `programme` 标签：start/stop 为 "yyyyMMddHHmmss +0800"，
/// 内部包含 `title` 与可选 `desc` 子标签。
class EpgParser {
  const EpgParser._();

  /// 从 XML 文本中解析指定频道的当日节目单（按开始时间升序）。
  ///
  /// [channelName] 为空时解析全部频道；返回的 map key 为节目单频道名。
  static Map<String, List<EpgProgram>> parse(
    String xml, {
    String? channelName,
  }) {
    final result = <String, List<EpgProgram>>{};
    if (xml.isEmpty) return result;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    // 用正则提取 programme 块（. 匹配换行）
    final re = RegExp(
      r'<programme\s+start="(\d{8}\d{6})(?:[^"]*)"\s+stop="(\d{8}\d{6})(?:[^"]*)"\s+channel="([^"]+)">(.*?)</programme>',
      dotAll: true,
    );

    for (final m in re.allMatches(xml)) {
      final start = _parseXmltvTime(m.group(1)!);
      final end = _parseXmltvTime(m.group(2)!);
      final channel = m.group(3)!.trim();
      if (channel.isEmpty) continue;

      // 只保留今天 0 点 ~ 明天 0 点的节目
      if (start.isBefore(todayStart) || !start.isBefore(tomorrowStart)) {
        continue;
      }

      final body = m.group(4)!;
      final title = _tagText(body, 'title') ?? '未知节目';
      final desc = _tagText(body, 'desc');

      final program = EpgProgram(
        start: start,
        end: end,
        channel: channel,
        title: title,
        desc: desc,
      );

      if (channelName == null || _sameChannel(channel, channelName)) {
        result.putIfAbsent(channel, () => []).add(program);
      }
    }

    for (final list in result.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }
    return result;
  }

  /// 解析 XMLTV 时间："20260810130000 +0800" -> DateTime
  static DateTime _parseXmltvTime(String raw) {
    final timePart = raw.length >= 14 ? raw.substring(0, 14) : raw;
    int? offsetMinutes;
    final offsetRe = RegExp(r'([+-])(\d{2})(\d{2})').firstMatch(raw);
    if (offsetRe != null) {
      final sign = offsetRe.group(1) == '+' ? 1 : -1;
      final hh = int.tryParse(offsetRe.group(2)!) ?? 0;
      final mm = int.tryParse(offsetRe.group(3)!) ?? 0;
      offsetMinutes = sign * (hh * 60 + mm);
    }

    final dt = DateTime(
      int.parse(timePart.substring(0, 4)),
      int.parse(timePart.substring(4, 6)),
      int.parse(timePart.substring(6, 8)),
      int.parse(timePart.substring(8, 10)),
      int.parse(timePart.substring(10, 12)),
      int.parse(timePart.substring(12, 14)),
    );
    // 转成本地时间
    return offsetMinutes == null ? dt : dt.subtract(Duration(minutes: offsetMinutes));
  }

  static String? _tagText(String xml, String tag) {
    final re = RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true);
    final m = re.firstMatch(xml);
    if (m == null) return null;
    final text = m.group(1)!.trim();
    if (text.isEmpty) return null;
    return text.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>');
  }

  /// 频道名匹配（大小写不敏感、忽略空白与符号；支持包含关系，
  /// 如 "CCTV-1 综合" 可匹配节目单中的 "CCTV-1"）。
  static bool _sameChannel(String epgChannel, String channel) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-+．.]'), '');
    final a = norm(epgChannel);
    final b = norm(channel);
    if (a == b) return true;
    return a.contains(b) || b.contains(a);
  }
}
