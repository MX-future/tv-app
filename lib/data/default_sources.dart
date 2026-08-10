import '../models/play_source.dart';

/// 内置直播源（fanmingming/live 公益项目，可直连访问）。
const List<PlaySource> kDefaultSources = [
  PlaySource(
    id: 'fanmingming_ipv6',
    name: 'fanmingming IPv6',
    url: 'https://live.fanmingming.cn/tv/m3u/ipv6.m3u',
    builtIn: true,
  ),
  PlaySource(
    id: 'fanmingming_index',
    name: 'fanmingming 综合',
    url: 'https://live.fanmingming.cn/tv/m3u/index.m3u',
    builtIn: true,
  ),
  PlaySource(
    id: 'fanmingming_itv',
    name: 'fanmingming ITV',
    url: 'https://live.fanmingming.cn/tv/m3u/itv.m3u',
    builtIn: true,
  ),
];
