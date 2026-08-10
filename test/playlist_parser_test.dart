// 播放列表解析器测试：m3u / txt / 自动识别 / 去重合并 / 分组归一化。
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_app/models/channel.dart';
import 'package:tv_app/models/play_source.dart';
import 'package:tv_app/services/playlist_parser.dart';

void main() {
  group('PlaylistParser.parseM3u', () {
    test('解析频道与属性', () {
      const content = '''
#EXTM3U x-tvg-url="https://live.fanmingming.cn/e.xml"
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="https://l/tv/CCTV1.png" group-title="央视频道",CCTV-1综合
http://example.com/cctv1.m3u8
#EXTINF:-1 tvg-name="CCTV2" tvg-logo="https://l/tv/CCTV2.png" group-title="央视频道",CCTV-2财经
http://example.com/cctv2.m3u8
''';
      final parsed = PlaylistParser.parse(content, sourceName: 'test');
      expect(parsed.epgUrl, 'https://live.fanmingming.cn/e.xml');
      expect(parsed.channels.length, 2);

      final c1 = parsed.channels[0];
      expect(c1.name, 'CCTV-1综合');
      expect(c1.group, '央视频道');
      expect(c1.tvgName, 'CCTV1');
      expect(c1.logo, 'https://l/tv/CCTV1.png');
      expect(c1.url, 'http://example.com/cctv1.m3u8');
      expect(c1.sourceName, 'test');
    });

    test('缺 EPG 时回退默认地址', () {
      const content = '''
#EXTM3U
#EXTINF:-1 group-title="卫视",北京卫视
http://example.com/bj.m3u8
''';
      final parsed = PlaylistParser.parse(content);
      expect(parsed.epgUrl, PlaySource.defaultEpgUrl);
      expect(parsed.channels.single.group, '卫视');
    });

    test('兼容 best-fan 源的额外属性（response-time 等）', () {
      const content = '''
#EXTM3U
#PLAYLIST: IPTV Channel List
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="https://gitee.com/x/y/raw/main/img/CCTV1.png" group-title="央视频道" response-time="120ms",CCTV-1
http://204.12.221.218:8181/3m1080p/cctv1.m3u8
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="https://gitee.com/x/y/raw/main/img/CCTV1.png" group-title="央视频道" response-time="150ms",CCTV-1
http://bztv.tvbus.cc:8081/cdnlive/cctv1.m3u8
''';
      final parsed = PlaylistParser.parse(content);
      expect(parsed.channels.length, 2);
      expect(parsed.channels[0].name, 'CCTV-1');
      expect(parsed.channels[0].tvgName, 'CCTV1');
      expect(parsed.channels[0].logo, contains('gitee.com'));
    });

    test('空行与注释行容错', () {
      const content = '''
#EXTM3U

#EXTINF:-1 group-title="央视频道",CCTV-1

http://example.com/cctv1.m3u8
#EXTINF:-1 group-title="央视频道",CCTV-2
http://example.com/cctv2.m3u8
#EXTVLCOPT:http-referrer=http://example.com
''';
      final parsed = PlaylistParser.parse(content);
      expect(parsed.channels.length, 2);
    });
  });

  group('PlaylistParser.parseTxt', () {
    test('解析 "频道名,URL" 行', () {
      const content = '''
# 注释行
CCTV-1 综合,http://example.com/cctv1.m3u8
北京卫视,http://example.com/bj.m3u8
invalid-line-without-comma
,http://no-name.m3u8
''';
      final channels = PlaylistParser.parseTxt(content, sourceName: 'txt');
      expect(channels.length, 2);
      expect(channels[1].name, '北京卫视');
      expect(channels[0].group, '未分组');
      expect(channels[0].sourceName, 'txt');
    });
  });

  group('PlaylistParser.parse 自动识别', () {
    test('以 #EXTM3U 开头识别为 m3u', () {
      final parsed = PlaylistParser.parse('#EXTM3U\n#EXTINF:-1 group-title="a",CCTV-1\nhttp://x/1.m3u8\n');
      expect(parsed.channels.length, 1);
      expect(parsed.epgUrl, PlaySource.defaultEpgUrl);
    });

    test('非 m3u 内容识别为 txt', () {
      final parsed = PlaylistParser.parse('CCTV-1,http://x/1.m3u8\n北京卫视,http://x/2.m3u8\n');
      expect(parsed.channels.length, 2);
      expect(parsed.epgUrl, isNull);
    });
  });

  group('PlaylistParser.mergeDuplicateChannels', () {
    test('同名频道合并，备用地址收集', () {
      const a = Channel(name: 'CCTV-1', group: '央视频道', url: 'http://a/1.m3u8', tvgName: 'CCTV1');
      const b = Channel(name: 'CCTV-1', group: '央视频道', url: 'http://b/2.m3u8', tvgName: 'CCTV1');
      const c = Channel(name: '北京卫视', group: '卫视频道', url: 'http://c/3.m3u8');
      final merged = PlaylistParser.mergeDuplicateChannels([a, b, c]);
      expect(merged.length, 2);
      final cctv1 = merged.first;
      expect(cctv1.url, 'http://a/1.m3u8');
      expect(cctv1.altUrls, ['http://b/2.m3u8']);
    });

    test('单元素列表直接返回', () {
      const a = Channel(name: 'CCTV-1', group: '央视频道', url: 'http://a/1.m3u8');
      expect(PlaylistParser.mergeDuplicateChannels([a]), [a]);
    });
  });

  group('分组归一化', () {
    test('央视台 → 央视频道，卫视台 → 卫视频道', () {
      const content = '''
#EXTM3U
#EXTINF:-1 group-title="央视台",CCTV-1
http://x/1.m3u8
#EXTINF:-1 group-title="卫视台",北京卫视
http://x/2.m3u8
#EXTINF:-1 group-title="数字频道",测试频道
http://x/3.m3u8
#EXTINF:-1 ,无名频道
http://x/4.m3u8
''';
      final parsed = PlaylistParser.parse(content);
      final groups = parsed.channels.map((c) => c.group).toList();
      expect(groups, ['央视频道', '卫视频道', '其他频道', '未分组']);
    });
  });
}
