// EPG（e.xml）解析器测试：XMLTV 时间、节目提取、今日过滤、频道匹配。
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_app/services/epg_parser.dart';

void main() {
  group('EpgParser.parse', () {
    test('解析 programme 块（标题/描述/时间）', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv generator-info-name="xmltv">
  <channel id="CCTV-1"><display-name>CCTV-1</display-name></channel>
  <programme start="20260810130000 +0800" stop="20260810140000 +0800" channel="CCTV-1">
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
      // 2026-08-10 13:00:00 +0800 = 本地 13:00（测试机若为 +0800 时区）
      expect(list.single.start.hour, 13);
      expect(list.single.end.hour, 14);
    });

    test('按频道名过滤（channelName 参数）', () {
      const xml = '''
<tv>
  <programme start="20260810100000 +0800" stop="20260810110000 +0800" channel="CCTV-1">
    <title>节目A</title>
  </programme>
  <programme start="20260810100000 +0800" stop="20260810110000 +0800" channel="CCTV-2">
    <title>节目B</title>
  </programme>
</tv>
''';
      final map = EpgParser.parse(xml, channelName: 'CCTV-1');
      expect(map.length, 1);
      expect(map['CCTV-1']!.single.title, '节目A');
    });

    test('频道名模糊匹配（CCTV-1 匹配 CCTV1）', () {
      const xml = '''
<tv>
  <programme start="20260810100000 +0800" stop="20260810110000 +0800" channel="CCTV1">
    <title>节目A</title>
  </programme>
</tv>
''';
      final map = EpgParser.parse(xml, channelName: 'CCTV-1 综合');
      expect(map['CCTV1']!.single.title, '节目A');
    });

    test('只保留今天（0点~24点）的节目', () {
      // 今天 2026-08-10 的样本；昨天/明天的节目应被过滤
      final now = DateTime.now();
      String pad(int n) => n.toString().padLeft(2, '0');
      final today = now;
      final yesterday = now.subtract(const Duration(days: 1));
      final tomorrow = now.add(const Duration(days: 1));
      String fmt(DateTime t, int h, int m) =>
          '${t.year}${pad(t.month)}${pad(t.day)}${pad(h)}${pad(m)}00';
      final xml = '''
<tv>
  <programme start="${fmt(today, 10, 0)} +0800" stop="${fmt(today, 11, 0)} +0800" channel="T">
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
      const xml = '''
<tv>
  <programme start="20260810140000 +0800" stop="20260810150000 +0800" channel="T">
    <title>后</title>
  </programme>
  <programme start="20260810100000 +0800" stop="20260810110000 +0800" channel="T">
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
      const xml = '''
<tv>
  <programme start="20260810100000 +0800" stop="20260810110000 +0800" channel="T">
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
