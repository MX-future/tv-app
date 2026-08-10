import 'package:flutter/material.dart';

import '../app.dart';
import '../models/channel.dart';
import '../widgets/channel_logo.dart';
import 'player_page.dart';

/// 收藏频道页（深炭黑 + 毛玻璃风格）。
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final favorites = state.channels.where((c) => state.isFavorite(c)).toList();
    final topPad = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('我的收藏'),
        flexibleSpace: const GlassAppBarBackdrop(),
      ),
      body: Padding(
        padding: EdgeInsets.only(top: topPad),
        child: favorites.isEmpty
            ? const _EmptyFavorites()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: favorites.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final channel = favorites[i];
                  return _FavoriteTile(
                    channel: channel,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlayerPage(
                          channels: favorites,
                          initialIndex: i,
                        ),
                      ),
                    ),
                    onRemove: () => state.toggleFavorite(channel),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_border, size: 56, color: Color(0xFF5A6472)),
          SizedBox(height: 12),
          Text(
            '还没有收藏的频道',
            style: TextStyle(fontSize: 14, color: Color(0xFF8E98A6)),
          ),
          SizedBox(height: 4),
          Text(
            '播放频道时点击右上角星标即可收藏',
            style: TextStyle(fontSize: 12, color: Color(0xFF5A6472)),
          ),
        ],
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.channel,
    required this.onTap,
    required this.onRemove,
  });

  final Channel channel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF242A33),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ChannelLogo(
            logoUrl: channel.logo,
            name: channel.name,
            size: 34,
          ),
        ),
        title: Text(
          channel.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF2F5F9),
          ),
        ),
        subtitle: Text(
          channel.group,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8E98A6)),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF5A6472)),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
