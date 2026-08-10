// 数据模型测试：Channel / PlaySource 序列化与字段逻辑。
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_app/models/channel.dart';
import 'package:tv_app/models/play_source.dart';

void main() {
  group('Channel 模型', () {
    test('toJson/fromJson 往返', () {
      const channel = Channel(
        name: 'CCTV-1',
        group: '央视频道',
        url: 'http://x/1.m3u8',
        tvgName: 'CCTV1',
        logo: 'http://l/1.png',
        sourceName: '测试源',
        altUrls: ['http://x/2.m3u8'],
        recentAt: null,
      );
      final restored = Channel.fromJson(channel.toJson());
      expect(restored.name, channel.name);
      expect(restored.group, channel.group);
      expect(restored.url, channel.url);
      expect(restored.tvgName, channel.tvgName);
      expect(restored.logo, channel.logo);
      expect(restored.sourceName, channel.sourceName);
      expect(restored.altUrls, ['http://x/2.m3u8']);
    });

    test('recentAt 时间戳往返', () {
      final t = DateTime(2026, 8, 10, 14, 30);
      final channel = const Channel(name: 'CCTV-1', group: 'a', url: 'u')
          .withRecentAt(t);
      final restored = Channel.fromJson(channel.toJson());
      expect(restored.recentAt, t);
    });

    test('缺字段时 fromJson 使用默认值', () {
      final channel = Channel.fromJson(const {'name': 'CCTV-1'});
      expect(channel.group, '未分组');
      expect(channel.url, '');
      expect(channel.altUrls, isEmpty);
      expect(channel.recentAt, isNull);
      expect(channel.sourceName, isNull);
    });

    test('id / epgKey / normalizedKey / candidates', () {
      const channel = Channel(
        name: 'CCTV-1综合',
        group: '央视频道',
        url: 'http://x/1.m3u8',
        tvgName: 'CCTV1',
        altUrls: ['http://x/2.m3u8'],
      );
      expect(channel.id, 'CCTV-1综合|http://x/1.m3u8');
      expect(channel.epgKey, 'CCTV1');
      expect(channel.normalizedKey, 'cctv1');
      expect(channel.candidates, ['http://x/1.m3u8', 'http://x/2.m3u8']);
    });

    test('normalizeName 忽略空格/符号', () {
      expect(Channel.normalizeName('CCTV-5+ 体育'), 'cctv5体育');
      expect(Channel.normalizeName('北京卫视'), '北京卫视');
    });

    test('withAltUrls 保留其他字段', () {
      final t = DateTime(2026, 8, 10);
      final channel = Channel(
        name: 'CCTV-1',
        group: '央视频道',
        url: 'u',
        tvgName: 'CCTV1',
        logo: 'l',
        sourceName: 's',
        recentAt: null,
      ).withRecentAt(t);
      final updated = channel.withAltUrls(['a', 'b']);
      expect(updated.altUrls, ['a', 'b']);
      expect(updated.name, 'CCTV-1');
      expect(updated.tvgName, 'CCTV1');
      expect(updated.logo, 'l');
      expect(updated.sourceName, 's');
      expect(updated.recentAt, t);
    });
  });

  group('PlaySource 模型', () {
    test('toJson/fromJson 往返（含 mirrors）', () {
      const source = PlaySource(
        id: 's1',
        name: '测试源',
        url: 'http://x/main.m3u',
        builtIn: true,
        epgUrl: 'http://x/e.xml',
        mirrors: ['http://x/m1.m3u', 'http://x/m2.m3u'],
      );
      final restored = PlaySource.fromJson(source.toJson());
      expect(restored.id, 's1');
      expect(restored.name, '测试源');
      expect(restored.url, 'http://x/main.m3u');
      expect(restored.builtIn, true);
      expect(restored.epgUrl, 'http://x/e.xml');
      expect(restored.mirrors, ['http://x/m1.m3u', 'http://x/m2.m3u']);
    });

    test('旧数据兼容（无 mirrors/epgUrl/builtIn 字段）', () {
      final source = PlaySource.fromJson(const {
        'name': '旧源',
        'url': 'http://x/old.m3u',
      });
      expect(source.id, contains('旧源'));
      expect(source.builtIn, false);
      expect(source.epgUrl, isNull);
      expect(source.mirrors, isEmpty);
    });

    test('candidates 顺序：主地址在前，镜像在后', () {
      const source = PlaySource(
        id: 's',
        name: '测试源',
        url: 'http://x/main.m3u',
        mirrors: ['http://x/m1.m3u'],
      );
      expect(source.candidates, ['http://x/main.m3u', 'http://x/m1.m3u']);
    });

    test('copyWith 保留 mirrors', () {
      const source = PlaySource(
        id: 's',
        name: '测试源',
        url: 'u',
        epgUrl: 'old',
        mirrors: ['m'],
      );
      final updated = source.copyWith(epgUrl: 'new');
      expect(updated.epgUrl, 'new');
      expect(updated.mirrors, ['m']);
      expect(updated.url, 'u');
    });
  });
}
