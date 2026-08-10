import 'package:flutter/material.dart';

import '../app.dart';
import 'channel_list_page.dart';
import 'favorites_page.dart';
import 'mine_page.dart';

/// 主框架：底部导航切换 直播 / 收藏 / 我的。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 内容延伸到底部导航之下，实现毛玻璃透出效果
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: const [
          ChannelListPage(),
          FavoritesPage(),
          MinePage(),
        ],
      ),
      bottomNavigationBar: GlassBox(
        sigma: 22,
        color: const Color(0xFFF2F7FF),
        alpha: 0.55,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.live_tv_outlined),
              selectedIcon: Icon(Icons.live_tv),
              label: '直播',
            ),
            NavigationDestination(
              icon: Icon(Icons.star_outline),
              selectedIcon: Icon(Icons.star),
              label: '收藏',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
