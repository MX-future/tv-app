import '../models/play_source.dart';

/// 内置直播源（best-fan/iptv-sources 开源项目，每日自动检测有效性）。
///
/// 每个源配置多个访问通道，按实测速度与可达性排序自动尝试：
/// 1. `cdn.jsdelivr.net`        —— 国内节点，实测最快（约 0.7s）
/// 2. `gh-proxy.com`            —— GitHub 加速反代（约 0.7s）
/// 3. `ghfast.top`              —— GitHub 加速反代（约 2.4s）
/// 4. `raw.githubusercontent.com` —— GitHub 原始地址（国内常被阻断）
/// 5. `raw.staticdn.net`        —— 国内加速代理（时好时坏）
///
/// 若全部网络通道均不可用，自动回退到打包在 App 内的离线快照
/// （[PlaySource.assetPath]），确保任何网络环境下都能进入频道列表。
///
/// 该源全部为 IPv4 直播流，无需 IPv6 网络；台标来自 Gitee 国内 CDN。
const List<PlaySource> kDefaultSources = [
  PlaySource(
    id: 'bestfan_cn_all',
    name: '全部频道',
    url: 'https://cdn.jsdelivr.net/gh/best-fan/iptv-sources@master/cn_all.m3u8',
    builtIn: true,
    assetPath: 'assets/playlists/cn_all.m3u8',
    mirrors: [
      'https://gh-proxy.com/https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_all.m3u8',
      'https://ghfast.top/https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_all.m3u8',
      'https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_all.m3u8',
      'https://raw.staticdn.net/best-fan/iptv-sources/master/cn_all.m3u8',
    ],
  ),
  PlaySource(
    id: 'bestfan_cn_cctv',
    name: '央视频道',
    url: 'https://cdn.jsdelivr.net/gh/best-fan/iptv-sources@master/cn_cctv.m3u8',
    builtIn: true,
    assetPath: 'assets/playlists/cn_cctv.m3u8',
    mirrors: [
      'https://gh-proxy.com/https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_cctv.m3u8',
      'https://ghfast.top/https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_cctv.m3u8',
      'https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_cctv.m3u8',
      'https://raw.staticdn.net/best-fan/iptv-sources/master/cn_cctv.m3u8',
    ],
  ),
  PlaySource(
    id: 'bestfan_cn_province',
    name: '卫视频道',
    url: 'https://cdn.jsdelivr.net/gh/best-fan/iptv-sources@master/cn_province.m3u8',
    builtIn: true,
    assetPath: 'assets/playlists/cn_province.m3u8',
    mirrors: [
      'https://gh-proxy.com/https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_province.m3u8',
      'https://ghfast.top/https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_province.m3u8',
      'https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_province.m3u8',
      'https://raw.staticdn.net/best-fan/iptv-sources/master/cn_province.m3u8',
    ],
  ),
  PlaySource(
    id: 'bestfan_cn_pay',
    name: '付费频道',
    url: 'https://cdn.jsdelivr.net/gh/best-fan/iptv-sources@master/cn_pay.m3u8',
    builtIn: true,
    assetPath: 'assets/playlists/cn_pay.m3u8',
    mirrors: [
      'https://gh-proxy.com/https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_pay.m3u8',
      'https://ghfast.top/https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_pay.m3u8',
      'https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_pay.m3u8',
      'https://raw.staticdn.net/best-fan/iptv-sources/master/cn_pay.m3u8',
    ],
  ),
];
