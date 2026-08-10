# 电视直播 TV App

基于 Flutter 开发的手机端电视直播应用，直播源来自开源公益项目 [fanmingming/live](https://github.com/fanmingming/live)。

## ✨ 功能特性

- 📺 **直播频道**：内置 fanmingming/live 多个源（IPv6 / 综合 / ITV），按分组展示（央视频道、卫视频道、地方频道等），带台标 Logo
- 🔍 **频道搜索**：按频道名快速过滤（支持 CCTV、卫视 等关键字）
- 📱 **全屏播放**：横屏沉浸式播放，基于 media_kit（libmpv 内核），兼容 HLS 等主流直播流格式
- 👆 **手势操作**：左右滑动切换频道，点击屏幕显示/隐藏菜单，播放失败一键重试或跳下一频道
- ⭐ **频道收藏**：收藏常用频道，首页一键直达
- 📅 **EPG 节目单**：解析 fanmingming 的 e.xml 接口，显示当前正在播出与接下来的节目
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

内置源默认使用 `live.fanmingming.cn` 域名（GitHub Actions 自动构建，CloudFlare 提供 CDN）：

| 源名称 | 地址 | 说明 |
| ------ | ---- | ---- |
| fanmingming IPv6 | `https://live.fanmingming.cn/tv/m3u/ipv6.m3u` | IPv6 直连源 |
| fanmingming 综合 | `https://live.fanmingming.cn/tv/m3u/index.m3u` | 综合频道列表 |
| fanmingming ITV | `https://live.fanmingming.cn/tv/m3u/itv.m3u` | ITV 频道列表 |

在 App「我的 → 添加自定义源」中可粘贴任意 m3u / txt 订阅链接，例如：

```
https://live.fanmingming.cn/tv/m3u/ipv6.m3u
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
