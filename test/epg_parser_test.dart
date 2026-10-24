// EPG（e.xml）解析器测试：XMLTV 时间、节目提取、今日过滤、频道匹配。
//
// 注意：EpgParser 只保留"当天"节目，因此测试数据必须使用动态的今天日期，
// 写死日期会导致测试随日期推移而失效。
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_app/services/epg_parser.dart';

/// 今天的 yyyyMMdd 时间戳前缀。
String todayStamp() {
  final now = DateTime.now();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${now.year}${p(now.month)}${p(now.day)}';
}

void main() {
  final ds = todayStamp();

  group('EpgParser.parse', () {
    test('解析 programme 块（标题/描述/时间）', () {
      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv generator-info-name="xmltv">
  <channel id="CCTV-1"><display-name>CCTV-1</display-name></channel>
  <programme start="${ds}130000 +0800" stop="${ds}140000 +0800" channel="CCTV-1">
    <title lang="zh">新闻30分</title>
    <desc lang="zh">今日要闻</desc>
  </programme>
</tv>
''';
      final map = EpgParser.parse(xml);
      expect(map.length, 1);
      final list = map['CCTV-1']!;
      expect(list.single.title, '新闻30分');
      expect(list.single.desc, '今日要闻');
      expect(list.single.channel, 'CCTV-1');
      // 13:00 +0800 = 本地 13:00（测试机为 +0800 时区）
      expect(list.single.start.hour, 13);
      expect(list.single.end.hour, 14);
    });

    test('按频道名过滤（channelName 参数）', () {
      final xml = '''
<tv>
  <programme start="${ds}100000 +0800" stop="${ds}110000 +0800" channel="CCTV-1">
    <title>节目A</title>
  </programme>
  <programme start="${ds}100000 +0800" stop="${ds}110000 +0800" channel="CCTV-2">
    <title>节目B</title>
  </programme>
</tv>
''';
      final map = EpgParser.parse(xml, channelName: 'CCTV-1');
      expect(map.length, 1);
      expect(map['CCTV-1']!.single.title, '节目A');
    });

    test('频道名模糊匹配（CCTV-1 匹配 CCTV1）', () {
      final xml = '''
<tv>
  <programme start="${ds}100000 +0800" stop="${ds}110000 +0800" channel="CCTV1">
    <title>节目A</title>
  </programme>
</tv>
''';
      final map = EpgParser.parse(xml, channelName: 'CCTV-1 综合');
      expect(map['CCTV1']!.single.title, '节目A');
    });

    test('只保留今天（0点~24点）的节目', () {
      final now = DateTime.now();
      String pad(int n) => n.toString().padLeft(2, '0');
      final yesterday = now.subtract(const Duration(days: 1));
      final tomorrow = now.add(const Duration(days: 1));
      String fmt(DateTime t, int h, int m) =>
          '${t.year}${pad(t.month)}${pad(t.day)}${pad(h)}${pad(m)}00';
      final xml = '''
<tv>
  <programme start="${fmt(now, 10, 0)} +0800" stop="${fmt(now, 11, 0)} +0800" channel="T">
    <title>今天节目</title>
  </programme>
  <programme start="${fmt(yesterday, 20, 0)} +0800" stop="${fmt(yesterday, 21, 0)} +0800" channel="T">
    <title>昨天节目</title>
  </programme>
  <programme start="${fmt(tomorrow, 8, 0)} +0800" stop="${fmt(tomorrow, 9, 0)} +0800" channel="T">
    <title>明天节目</title>
  </programme>
</tv>
''';
      final map = EpgParser.parse(xml);
      final titles = map.values.expand((e) => e).map((p) => p.title).toList();
      expect(titles, ['今天节目']);
    });

    test('按开始时间升序排序', () {
      final xml = '''
<tv>
  <programme start="${ds}140000 +0800" stop="${ds}150000 +0800" channel="T">
    <title>后</title>
  </programme>
  <programme start="${ds}100000 +0800" stop="${ds}110000 +0800" channel="T">
    <title>先</title>
  </programme>
</tv>
''';
      final map = EpgParser.parse(xml);
      final titles = map['T']!.map((p) => p.title).toList();
      expect(titles, ['先', '后']);
    });

    test('空输入与无 programme 的输入不崩溃', () {
      expect(EpgParser.parse(''), isEmpty);
      expect(EpgParser.parse('<tv></tv>'), isEmpty);
      expect(EpgParser.parse('garbage'), isEmpty);
    });

    test('desc 缺失时 title 兜底', () {
      final xml = '''
<tv>
  <programme start="${ds}100000 +0800" stop="${ds}110000 +0800" channel="T">
    <title>仅有标题</title>
  </programme>
</tv>
''';
      final list = EpgParser.parse(xml)['T']!;
      expect(list.single.title, '仅有标题');
      expect(list.single.desc, isNull);
    });
  });
}
