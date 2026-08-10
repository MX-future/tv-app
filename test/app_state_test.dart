// AppState 状态逻辑测试：频道加载、镜像切换、收藏、最近播放、候选池。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv_app/models/channel.dart';
import 'package:tv_app/models/play_source.dart';
import 'package:tv_app/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleSource = PlaySource(
    id: 'test_source',
    name: '测试源',
    url: 'http://x/list.m3u',
    mirrors: ['http://x/mirror.m3u'],
  );

  const m3uContent = '''
#EXTM3U x-tvg-url="http://x/e.xml"
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="http://l/CCTV1.png" group-title="央视频道",CCTV-1
http://a/1.m3u8
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="http://l/CCTV1.png" group-title="央视频道",CCTV-1
http://b/2.m3u8
#EXTINF:-1 tvg-name="北京卫视" group-title="卫视频道",北京卫视
http://c/3.m3u8
''';

  AppState buildState() {
    final state = AppState();
    // 默认注入假数据源
    state.fetchText = (url) async {
      if (url == sampleSource.url) return m3uContent;
      if (url == sampleSource.mirrors.first) return m3uContent;
      throw Exception('HTTP 404（$url）');
    };
    return state;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('loadChannels', () {
    test('成功：频道合并、分组、altUrls、EPG 地址', () async {
      final state = buildState();
      await state.loadChannels(sampleSource);

      expect(state.channels.length, 2); // CCTV-1 两个条目合并
      expect(state.groups, ['央视频道', '卫视频道']);

      final cctv1 = state.channels.first;
      expect(cctv1.name, 'CCTV-1');
      expect(cctv1.url, 'http://a/1.m3u8');
      expect(cctv1.altUrls, ['http://b/2.m3u8']);

      expect(state.activeSource?.id, 'test_source');
      expect(state.epgUrl, 'http://x/e.xml');
      expect(state.loadError, isNull);
      expect(state.loading, false);
    });

    test('主地址失败自动尝试镜像并提示', () async {
      final state = buildState();
      state.fetchText = (url) async {
        if (url == sampleSource.url) throw Exception('HTTP 403（$url）');
        return m3uContent;
      };
      await state.loadChannels(sampleSource);

      expect(state.loadError, isNull);
      expect(state.channels.length, 2);
      expect(state.fallbackNote, contains('已自动使用'));
      expect(state.activeSource?.id, 'test_source');
    });

    test('全部地址失败：loadError 非空', () async {
      final state = buildState();
      state.fetchText = (url) async => throw Exception('连接超时（$url）');
      await state.loadChannels(sampleSource);

      expect(state.loadError, contains('连接超时'));
      expect(state.channels, isEmpty);
      expect(state.fallbackNote, isNull);
    });

    test('播放列表为空时报错', () async {
      final state = buildState();
      state.fetchText = (url) async => '#EXTM3U\n';
      await state.loadChannels(sampleSource);

      expect(state.loadError, contains('播放列表为空'));
    });
  });

  group('收藏', () {
    test('toggle 添加/移除并持久化', () async {
      final state = buildState();
      await state.loadChannels(sampleSource);
      final cctv1 = state.channels.first;

      expect(state.isFavorite(cctv1), false);
      await state.toggleFavorite(cctv1);
      expect(state.isFavorite(cctv1), true);

      // 从持久化读取
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('favorites'), isNotNull);

      await state.toggleFavorite(cctv1);
      expect(state.isFavorite(cctv1), false);
    });
  });

  group('最近播放', () {
    test('addRecent 去重置顶并记录时间', () async {
      final state = buildState();
      await state.loadChannels(sampleSource);
      final a = state.channels[0];
      final b = state.channels[1];

      await state.addRecent(a);
      await state.addRecent(b);
      await state.addRecent(a); // 再次播放 a，应置顶

      expect(state.recent.length, 2);
      expect(state.recent.first.id, a.id);
      expect(state.recent.first.recentAt, isNotNull);
    });

    test('removeRecent 删除单条', () async {
      final state = buildState();
      await state.loadChannels(sampleSource);
      await state.addRecent(state.channels[0]);
      await state.addRecent(state.channels[1]);

      await state.removeRecent(state.channels[0]);
      expect(state.recent.length, 1);
      expect(state.recent.first.id, state.channels[1].id);
    });

    test('clearRecent 清空', () async {
      final state = buildState();
      await state.loadChannels(sampleSource);
      await state.addRecent(state.channels[0]);
      await state.clearRecent();
      expect(state.recent, isEmpty);
    });

    test('超过 30 条自动裁剪', () async {
      final state = buildState();
      await state.loadChannels(sampleSource);
      for (var i = 0; i < 40; i++) {
        final c = Channel(
          name: '频道$i',
          group: 'g',
          url: 'http://x/$i.m3u8',
        );
        await state.addRecent(c);
      }
      expect(state.recent.length, 30);
    });
  });

  group('candidateUrls 候选池', () {
    test('聚合主地址、altUrls 与跨源池', () async {
      final state = buildState();
      await state.loadChannels(sampleSource);
      final cctv1 = state.channels.first;

      final candidates = state.candidateUrls(cctv1);
      expect(candidates.first, 'http://a/1.m3u8');
      expect(candidates, contains('http://b/2.m3u8'));
      // 去重
      expect(candidates.toSet().length, candidates.length);
    });
  });

  group('init', () {
    test('恢复上次使用的源', () async {
      SharedPreferences.setMockInitialValues({
        'last_source_id': 'bestfan_cn_all',
      });
      final state = buildState();
      // 内置源全部用假数据
      state.fetchText = (url) async {
        if (url.contains('bestfan_cn_all') || url.contains('cn_all')) {
          return m3uContent;
        }
        throw Exception('unexpected $url');
      };
      await state.init();

      expect(state.activeSource?.id, 'bestfan_cn_all');
      expect(state.channels, isNotEmpty);
    });

    test('无上次记录时回退第一个内置源', () async {
      final state = buildState();
      state.fetchText = (url) async {
        if (url.contains('cn_all.m3u8')) return m3uContent;
        throw Exception('unexpected $url');
      };
      await state.init();

      expect(state.activeSource, isNotNull);
      expect(state.channels, isNotEmpty);
      expect(state.sources.length, 4); // 4 个内置源
    });

    test('自定义源优先于内置源', () async {
      SharedPreferences.setMockInitialValues({
        'custom_sources': [
          '{"id":"custom_1","name":"我的源","url":"http://x/custom.m3u","builtIn":false}'
        ],
      });
      final state = buildState();
      state.fetchText = (url) async {
        if (url == 'http://x/custom.m3u') return m3uContent;
        throw Exception('unexpected $url');
      };
      await state.init();

      expect(state.sources.first.name, '我的源');
      expect(state.activeSource?.id, 'custom_1');
    });
  });

  group('设置', () {
    test('keepScreenOn / wifiOnly 持久化', () async {
      final state = buildState();
      await state.setKeepScreenOn(false);
      expect(state.keepScreenOn, false);

      await state.setWifiOnly(true);
      expect(state.wifiOnly, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('keep_screen_on'), false);
      expect(prefs.getBool('wifi_only'), true);
    });
  });
}
