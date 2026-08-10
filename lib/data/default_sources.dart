import '../models/play_source.dart';

/// 内置直播源（fanmingming/live 公益项目）。
///
/// 每个源配置多个镜像域名，按顺序自动尝试：
/// 1. `live.fanmingming.cn` —— CloudFlare Pages 构建，国内可直连
/// 2. `live.fanmingming.com` —— GitHub Pages 构建
/// 3. `raw.githubusercontent.com` —— 源仓库原始文件
const List<PlaySource> kDefaultSources = [
  PlaySource(
    id: 'fanmingming_ipv6',
    name: 'fanmingming IPv6',
    url: 'https://live.fanmingming.cn/tv/m3u/ipv6.m3u',
    builtIn: true,
    mirrors: [
      'https://live.fanmingming.com/tv/m3u/ipv6.m3u',
      'https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/ipv6.m3u',
    ],
  ),
  PlaySource(
    id: 'fanmingming_index',
    name: 'fanmingming 综合',
    url: 'https://live.fanmingming.cn/tv/m3u/index.m3u',
    builtIn: true,
    mirrors: [
      'https://live.fanmingming.com/tv/m3u/index.m3u',
      'https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/index.m3u',
    ],
  ),
  PlaySource(
    id: 'fanmingming_itv',
    name: 'fanmingming ITV',
    url: 'https://live.fanmingming.cn/tv/m3u/itv.m3u',
    builtIn: true,
    mirrors: [
      'https://live.fanmingming.com/tv/m3u/itv.m3u',
      'https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/itv.m3u',
    ],
  ),
];
