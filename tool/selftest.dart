// 纯 Dart 自检脚本：验证核心逻辑（沙箱内 flutter_tester 不可用时的替代执行）。
// 与 test/*_test.dart 覆盖相同逻辑；本地可用 `flutter test` 运行标准测试。
import 'dart:io';

import 'package:tv_app/models/channel.dart';
import 'package:tv_app/models/play_source.dart';
import 'package:tv_app/services/epg_parser.dart';
import 'package:tv_app/services/playlist_parser.dart';

int _pass = 0;
int _fail = 0;
final List<String> _errors = [];

void eq<T>(T actual, T expected, String label) {
  bool same;
  if (actual is List && expected is List) {
    same = actual.length == expected.length &&
        actual.asMap().entries.every((e) => e.value == expected[e.key]);
  } else {
    same = actual == expected;
  }
  if (same) {
    _pass++;
  } else {
    _fail++;
    _errors.add('[$label] 期望: $expected, 实际: $actual');
  }
}

void ok(bool cond, String label) {
  if (cond) {
    _pass++;
  } else {
    _fail++;
    _errors.add('[$label] 断言失败');
  }
}

void section(String name) => stdout.writeln('== $name ==');

void testPlaylistParser() {
  section('PlaylistParser');
  // m3u 基本解析
  final parsed = PlaylistParser.parse('''
#EXTM3U x-tvg-url="https://live.fanmingming.cn/e.xml"
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="https://l/tv/CCTV1.png" group-title="央视频道",CCTV-1综合
http://example.com/cctv1.m3u8
''', sourceName: 't');
  eq(parsed.epgUrl, 'https://live.fanmingming.cn/e.xml', 'm3u epg url');
  eq(parsed.channels.length, 1, 'm3u 频道数');
  eq(parsed.channels[0].name, 'CCTV-1综合', '频道名');
  eq(parsed.channels[0].group, '央视频道', '分组');
  eq(parsed.channels[0].tvgName, 'CCTV1', 'tvg-name');
  eq(parsed.channels[0].logo, 'https://l/tv/CCTV1.png', 'tvg-logo');
  eq(parsed.channels[0].sourceName, 't', 'sourceName');

  // 缺 EPG 回退
  final p2 = PlaylistParser.parse('#EXTM3U\n#EXTINF:-1 group-title="卫视",北京卫视\nhttp://x/bj.m3u8\n');
  eq(p2.epgUrl, PlaySource.defaultEpgUrl, 'EPG 回退');

  // best-fan 风格（response-time 属性 + 多条目）
  final p3 = PlaylistParser.parse('''
#EXTM3U
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="https://gitee.com/x/y/raw/main/img/CCTV1.png" group-title="央视频道" response-time="120ms",CCTV-1
http://204.12.221.218:8181/3m1080p/cctv1.m3u8
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="https://gitee.com/x/y/raw/main/img/CCTV1.png" group-title="央视频道" response-time="150ms",CCTV-1
http://bztv.tvbus.cc:8081/cdnlive/cctv1.m3u8
''');
  eq(p3.channels.length, 2, 'best-fan 条目数');
  eq(p3.channels[0].name, 'CCTV-1', 'best-fan 频道名');

  // txt 解析
  final txt = PlaylistParser.parseTxt('CCTV-1 综合,http://x/1.m3u8\n北京卫视,http://x/2.m3u8\n,http://x/no.m3u8\n');
  eq(txt.length, 2, 'txt 频道数');
  eq(txt[0].group, '未分组', 'txt 默认分组');

  // 自动识别
  ok(PlaylistParser.parse('CCTV-1,http://x/1.m3u8\n').channels.length == 1, 'txt 自动识别');

  // 合并去重
  const ca = Channel(name: 'CCTV-1', group: '央视频道', url: 'http://a/1.m3u8', tvgName: 'CCTV1');
  const cb = Channel(name: 'CCTV-1', group: '央视频道', url: 'http://b/2.m3u8', tvgName: 'CCTV1');
  const cc = Channel(name: '北京卫视', group: '卫视频道', url: 'http://c/3.m3u8');
  final merged = PlaylistParser.mergeDuplicateChannels([ca, cb, cc]);
  eq(merged.length, 2, '合并后数量');
  eq(merged[0].altUrls, ['http://b/2.m3u8'], '备用地址');
  eq(merged[0].url, 'http://a/1.m3u8', '保留主地址');

  // 分组归一化
  final p4 = PlaylistParser.parse('''
#EXTM3U
#EXTINF:-1 group-title="央视台",CCTV-1
http://x/1.m3u8
#EXTINF:-1 group-title="卫视台",北京卫视
http://x/2.m3u8
#EXTINF:-1 group-title="数字频道",测试
http://x/3.m3u8
#EXTINF:-1 ,无名
http://x/4.m3u8
''');
  final groups = p4.channels.map((c) => c.group).toList();
  eq(groups, ['央视频道', '卫视频道', '其他频道', '未分组'], '分组归一化');
}

void testEpgParser() {
  section('EpgParser');
  final xml = '''
<tv>
  <programme start="20260810130000 +0800" stop="20260810140000 +0800" channel="CCTV-1">
    <title lang="zh">新闻30分</title>
    <desc lang="zh">今日要闻</desc>
  </programme>
  <programme start="20260810150000 +0800" stop="20260810160000 +0800" channel="CCTV-2">
    <title>节目B</title>
  </programme>
</tv>
''';
  final map = EpgParser.parse(xml);
  eq(map.length, 2, 'EPG 频道数');
  final l1 = map['CCTV-1']!;
  eq(l1.single.title, '新闻30分', '标题');
  eq(l1.single.desc, '今日要闻', '描述');
  eq(l1.single.start.hour, 13, '开始时间小时');

  // 频道过滤
  final f = EpgParser.parse(xml, channelName: 'CCTV-2');
  eq(f.length, 1, '过滤后频道数');
  eq(f['CCTV-2']!.single.title, '节目B', '过滤正确');

  // 模糊匹配
  final fuzzy = EpgParser.parse(xml, channelName: 'CCTV-1 综合');
  ok(fuzzy.containsKey('CCTV-1'), '模糊匹配');

  // 排序
  final sorted = EpgParser.parse('''
<tv>
  <programme start="20260810140000 +0800" stop="20260810150000 +0800" channel="T">
    <title>后</title>
  </programme>
  <programme start="20260810100000 +0800" stop="20260810110000 +0800" channel="T">
    <title>先</title>
  </programme>
</tv>
''');
  eq(sorted['T']!.map((p) => p.title).toList(), ['先', '后'], '时间排序');

  // 空输入
  ok(EpgParser.parse('').isEmpty, '空输入');
  ok(EpgParser.parse('garbage').isEmpty, '无效输入');
}

void testModels() {
  section('Channel / PlaySource 模型');
  final t = DateTime(2026, 8, 10, 14, 30);
  const ch = Channel(
    name: 'CCTV-1',
    group: '央视频道',
    url: 'http://x/1.m3u8',
    tvgName: 'CCTV1',
    logo: 'l',
    sourceName: 's',
    altUrls: ['http://x/2.m3u8'],
  );
  final restored = Channel.fromJson(ch.toJson());
  eq(restored.name, 'CCTV-1', 'channel json 名称');
  eq(restored.altUrls, ['http://x/2.m3u8'], 'channel json altUrls');
  eq(ch.id, 'CCTV-1|http://x/1.m3u8', 'channel id');
  eq(ch.normalizedKey, 'cctv1', 'normalizedKey');
  eq(ch.candidates, ['http://x/1.m3u8', 'http://x/2.m3u8'], 'candidates');

  final withTime = ch.withRecentAt(t);
  eq(withTime.recentAt, t, 'withRecentAt');
  eq(Channel.fromJson(withTime.toJson()).recentAt, t, 'recentAt json 往返');
  eq(withTime.withAltUrls(['z']).name, 'CCTV-1', 'withAltUrls 保留字段');

  const ps = PlaySource(
    id: 's1',
    name: '测试源',
    url: 'http://x/main.m3u',
    builtIn: true,
    epgUrl: 'http://x/e.xml',
    mirrors: ['http://x/m1.m3u'],
  );
  final ps2 = PlaySource.fromJson(ps.toJson());
  eq(ps2.mirrors, ['http://x/m1.m3u'], 'PlaySource mirrors');
  eq(ps2.builtIn, true, 'PlaySource builtIn');
  eq(ps.candidates, ['http://x/main.m3u', 'http://x/m1.m3u'], 'PlaySource candidates');

  // 旧数据兼容
  final legacy = PlaySource.fromJson(const {'name': '旧源', 'url': 'http://x/o.m3u'});
  eq(legacy.builtIn, false, '旧数据 builtIn');
  ok(legacy.mirrors.isEmpty, '旧数据 mirrors');
}

Future<void> main() async {
  stdout.writeln('=== tv-app 核心逻辑自检 ===');
  testPlaylistParser();
  testEpgParser();
  testModels();

  stdout.writeln('\n结果: PASS $_pass / FAIL $_fail');
  if (_errors.isNotEmpty) {
    stdout.writeln('\n失败明细:');
    for (final e in _errors) {
      stdout.writeln('  ✗ $e');
    }
    exit(1);
  }
  stdout.writeln('全部通过 ✅');
}
