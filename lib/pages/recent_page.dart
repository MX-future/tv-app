import 'package:flutter/material.dart';

import '../app.dart';
import '../models/channel.dart';
import '../widgets/channel_logo.dart';
import 'player_page.dart';

/// 最近播放记录页（Apple Music 风格扁平列表）。
class RecentPage extends StatelessWidget {
  const RecentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final recent = state.recent;
    final topPad = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('最近播放'),
        flexibleSpace: const GlassAppBarBackdrop(),
      ),
      body: Padding(
        padding: EdgeInsets.only(top: topPad),
        child: recent.isEmpty
            ? const _EmptyRecent()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: recent.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 70,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                itemBuilder: (context, i) {
                  final channel = recent[i];
                  return _RecentTile(
                    channel: channel,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlayerPage(
                          channels: recent,
                          initialIndex: i,
                        ),
                      ),
                    ),
                    onRemove: () => state.removeRecent(channel),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 56, color: Color(0xFF48484A)),
          SizedBox(height: 12),
          Text(
            '还没有播放记录',
            style: TextStyle(fontSize: 14, color: Color(0xFF98989D)),
          ),
          SizedBox(height: 4),
          Text(
            '播放过的频道会出现在这里',
            style: TextStyle(fontSize: 12, color: Color(0xFF48484A)),
          ),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.channel,
    required this.onTap,
    required this.onRemove,
  });

  final Channel channel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF151517),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFFFFFFFF),
        ),
      ),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              channel.group,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF98989D)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(channel.recentAt),
            style: const TextStyle(fontSize: 11, color: Color(0xFF48484A)),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18, color: Color(0xFF48484A)),
        onPressed: onRemove,
      ),
    );
  }

  /// 相对时间：刚刚 / N分钟前 / 今天 HH:mm / 昨天 HH:mm / N天前 / M月D日。
  static String _formatTime(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    String two(int n) => n.toString().padLeft(2, '0');
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (now.day == t.day && now.month == t.month && now.year == t.year) {
      return '今天 ${two(t.hour)}:${two(t.minute)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.day == t.day &&
        yesterday.month == t.month &&
        yesterday.year == t.year) {
      return '昨天 ${two(t.hour)}:${two(t.minute)}';
    }
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${t.month}月${t.day}日';
  }
}
