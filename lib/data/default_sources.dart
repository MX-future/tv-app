import '../models/play_source.dart';

/// 内置直播源（best-fan/iptv-sources 开源项目，每日自动检测有效性）。
///
/// 每个源配置镜像地址，按顺序自动尝试：
/// 1. `raw.githubusercontent.com` —— GitHub 原始文件
/// 2. `raw.staticdn.net` —— 国内加速代理
///
/// 该源全部为 IPv4 / HTTPS 直播流，无需 IPv6 网络；台标来自 Gitee 国内 CDN。
const List<PlaySource> kDefaultSources = [
  PlaySource(
    id: 'bestfan_cn_all',
    name: '全部频道',
    url: 'https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_all.m3u8',
    builtIn: true,
    mirrors: [
      'https://raw.staticdn.net/best-fan/iptv-sources/master/cn_all.m3u8',
    ],
  ),
  PlaySource(
    id: 'bestfan_cn_cctv',
    name: '央视频道',
    url: 'https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_cctv.m3u8',
    builtIn: true,
    mirrors: [
      'https://raw.staticdn.net/best-fan/iptv-sources/master/cn_cctv.m3u8',
    ],
  ),
  PlaySource(
    id: 'bestfan_cn_province',
    name: '卫视频道',
    url: 'https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_province.m3u8',
    builtIn: true,
    mirrors: [
      'https://raw.staticdn.net/best-fan/iptv-sources/master/cn_province.m3u8',
    ],
  ),
  PlaySource(
    id: 'bestfan_cn_pay',
    name: '付费频道',
    url: 'https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_pay.m3u8',
    builtIn: true,
    mirrors: [
      'https://raw.staticdn.net/best-fan/iptv-sources/master/cn_pay.m3u8',
    ],
  ),
];
