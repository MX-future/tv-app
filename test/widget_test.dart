// 播放列表解析器单元测试。
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_app/services/playlist_parser.dart';

void main() {
  group('PlaylistParser.parseM3u', () {
    test('解析 m3u 频道与属性', () {
      const content = '''
#EXTM3U x-tvg-url="https://live.fanmingming.cn/e.xml"
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="https://live.fanmingming.cn/tv/CCTV1.png" group-title="央视频道",CCTV-1综合
http://example.com/cctv1.m3u8
#EXTINF:-1 tvg-name="CCTV2" tvg-logo="https://live.fanmingming.cn/tv/CCTV2.png" group-title="央视频道",CCTV-2财经
http://example.com/cctv2.m3u8
''';
      final parsed = PlaylistParser.parse(content, sourceName: 'test');
      expect(parsed.epgUrl, 'https://live.fanmingming.cn/e.xml');
      expect(parsed.channels.length, 2);

      final c1 = parsed.channels[0];
      expect(c1.name, 'CCTV-1综合');
      expect(c1.group, '央视频道');
      expect(c1.tvgName, 'CCTV1');
      expect(c1.logo, 'https://live.fanmingming.cn/tv/CCTV1.png');
      expect(c1.url, 'http://example.com/cctv1.m3u8');
    });

    test('缺 EPG 时回退默认地址', () {
      const content = '''
#EXTM3U
#EXTINF:-1 group-title="卫视",北京卫视
http://example.com/bj.m3u8
''';
      final parsed = PlaylistParser.parse(content);
      expect(parsed.epgUrl, 'https://live.fanmingming.cn/e.xml');
      expect(parsed.channels.single.group, '卫视');
    });
  });

  group('PlaylistParser.parseTxt', () {
    test('解析 "频道名,URL" 行', () {
      const content = '''
# 注释行
CCTV-1 综合,http://example.com/cctv1.m3u8
北京卫视,http://example.com/bj.m3u8
invalid-line-without-comma
''';
      final channels = PlaylistParser.parseTxt(content, sourceName: 'txt');
      expect(channels.length, 2);
      expect(channels[1].name, '北京卫视');
      expect(channels[0].group, '未分组');
    });
  });
}
