# 电视直播 TV App

基于 Flutter 开发的手机端电视直播应用，直播源来自开源公益项目 [best-fan/iptv-sources](https://github.com/best-fan/iptv-sources)（每日自动检测有效性，全 IPv4/HTTPS 源）。

## ✨ 功能特性

- 📺 **直播频道**：内置 best-fan/iptv-sources 分类源（全部 / 央视 / 卫视 / 付费），按分组展示，带台标 Logo（Gitee 国内 CDN）
- 🔍 **频道搜索**：按频道名快速过滤（支持 CCTV、卫视 等关键字）
- 📱 **全屏播放**：横屏沉浸式播放，基于 media_kit（libmpv 内核），兼容 HLS 等主流直播流格式
- 👆 **手势操作**：左右滑动切换频道，点击屏幕显示/隐藏菜单，播放失败自动切换备用源
- 🔄 **多源容灾**：同一频道聚合多个可用地址，播放失败自动按序尝试，全部失败给出明确提示
- ⭐ **频道收藏**：收藏常用频道，首页一键直达
- 📅 **EPG 节目单**：解析节目单接口，显示当前正在播出与接下来的节目
- 🔗 **自定义源**：支持添加任意 m3u / txt 订阅链接，自动识别格式
- 💾 **本地存储**：收藏、最近播放、自定义源、设置项均保存在本地
- 🔆 **屏幕常亮**：全屏播放时保持屏幕不熄灭（可关闭）

## 🛠️ 技术栈

| 模块 | 选型 |
| ---- | ---- |
| 框架 | Flutter 3.x（Dart 3.x） |
| 播放内核 | media_kit + media_kit_video（libmpv / libmdk） |
| 持久化 | shared_preferences |
| 网络请求 | http |

## 🚀 构建运行

### 环境要求

- Flutter SDK 3.16+（含 Dart 3）
- Android SDK（API 33+）或 Xcode（iOS）

### 运行

```bash
flutter pub get
flutter run
```

### 构建 APK

```bash
flutter build apk --release
# 产物位于 build/app/outputs/flutter-apk/app-release.apk
```

### 构建 iOS

```bash
flutter build ios --release
```

> 注意：部分直播流为 http 明文地址，Android 已开启 `usesCleartextTraffic`，iOS 已配置 `NSAllowsArbitraryLoads`，无需额外设置即可播放。

## 📖 直播源说明

内置源来自 [best-fan/iptv-sources](https://github.com/best-fan/iptv-sources)，由 Jenkins 每日自动采集并检测有效性（响应时间、可播放性），全部为 IPv4 地址，无需 IPv6 网络：

| 源名称 | 文件 | 说明 |
| ------ | ---- | ---- |
| 全部频道 | `cn_all.m3u8` | 完整列表（央视+卫视+付费+体育+卡通等），单频道多源 |
| 央视频道 | `cn_cctv.m3u8` | CCTV-1 ~ 17、4K 等 |
| 卫视频道 | `cn_province.m3u8` | 省级卫视 |
| 付费频道 | `cn_pay.m3u8` | 凤凰、金鹰等 |

### 三层容错，保证不出现「加载失败」

GitHub 原始地址（`raw.githubusercontent.com`）在国内经常被阻断，因此每个源配置 **5 个访问通道**，**并发竞速**取最快响应者：

| 顺序 | 通道 | 实测 |
| ---- | ---- | ---- |
| 1 | `cdn.jsdelivr.net/gh/best-fan/iptv-sources@master/…` | ~0.7s ✅ |
| 2 | `gh-proxy.com/https://raw.githubusercontent.com/…` | ~0.7s ✅ |
| 3 | `ghfast.top/https://raw.githubusercontent.com/…` | ~2.4s ✅ |
| 4 | `raw.githubusercontent.com/…` | 国内常被阻断 |
| 5 | `raw.staticdn.net/…` | 时好时坏 |

- **并发竞速**：所有通道同时请求，最快者胜出——最坏等待时间等于单次超时（10s），而不是 N 倍
- **跨源兜底**：当前源全军覆没时，自动换其他内置源再试
- **内置离线快照**：上述全部失败时，读取打包在 App 内的 `assets/playlists/*.m3u8`（326 条频道，随版本更新），**任何网络环境下都能进入频道列表**

同一频道在源文件里常有 5~8 个播放地址，已去重合并为一个频道条目，播放失败时自动顺延切换（页面顶部显示「备用源 x/n」）。

在 App「我的 → 添加自定义源」中可粘贴任意 m3u / txt 订阅链接，例如：

```
https://cdn.jsdelivr.net/gh/best-fan/iptv-sources@master/cn_all.m3u8
https://raw.githubusercontent.com/你的账号/你的仓库/main/live.m3u
```

## 📁 项目结构

```
lib/
├── main.dart                     # 入口（初始化 media_kit）
├── app.dart                      # 根组件 + 全局状态作用域
├── models/
│   ├── channel.dart              # 频道模型
│   ├── play_source.dart          # 直播源模型
│   └── epg_program.dart          # EPG 节目模型
├── data/
│   └── default_sources.dart      # 内置直播源
├── services/
│   ├── playlist_parser.dart      # m3u / txt 播放列表解析
│   ├── epg_parser.dart           # e.xml 节目单解析
│   └── stream_loader.dart        # 网络请求
├── state/
│   ├── app_state.dart            # 全局状态管理
│   └── settings_store.dart       # 本地持久化
├── pages/
│   ├── home_page.dart            # 主框架（底部导航）
│   ├── channel_list_page.dart    # 频道列表
│   ├── player_page.dart          # 全屏播放
│   ├── favorites_page.dart       # 收藏
│   └── mine_page.dart            # 源管理 + 设置
└── widgets/
    └── channel_logo.dart         # 台标组件
```

## ⚠️ 免责声明

- 本项目仅用于学习与技术交流，直播源及 EPG 数据来自互联网公开资源，版权归原作者所有
- 请勿将本项目用于商业用途或非法传播
- 部分源可能因网络环境（如 IPv6）无法访问，可切换其他源或添加自定义源

## 📄 License

[MIT](LICENSE)
