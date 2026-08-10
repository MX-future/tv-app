import 'package:flutter/material.dart';

import '../app.dart';
import '../models/channel.dart';
import '../state/app_state.dart';
import '../widgets/channel_logo.dart';
import 'player_page.dart';

/// 直播频道列表页（深炭黑 + 毛玻璃风格）。
class ChannelListPage extends StatefulWidget {
  const ChannelListPage({super.key});

  @override
  State<ChannelListPage> createState() => _ChannelListPageState();
}

class _ChannelListPageState extends State<ChannelListPage> {
  String _query = '';

  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF98989D);
  static const _textTertiary = Color(0xFF48484A);
  static const _primary = Color(0xFFFA2D48);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final topPad = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('电视直播'),
        actions: [
          IconButton(
            tooltip: '刷新频道',
            icon: const Icon(Icons.refresh),
            onPressed: state.loading
                ? null
                : () {
                    final s = state.activeSource;
                    if (s != null) state.loadChannels(s);
                  },
          ),
        ],
        // 深色毛玻璃层
        flexibleSpace: const GlassAppBarBackdrop(),
      ),
      body: Padding(
        padding: EdgeInsets.only(top: topPad),
        child: Column(
          children: [
            _buildSourceBar(state),
            if (state.loading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: _primary,
                backgroundColor: Colors.transparent,
              ),
            _buildSearchBar(),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  // ---------- 源切换条 ----------

  Widget _buildSourceBar(AppState state) {
    if (state.sources.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: state.sources.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final source = state.sources[i];
          final selected = state.activeSource?.id == source.id;
          return ChoiceChip(
            label: Text(source.name),
            selected: selected,
            onSelected: (_) {
              if (!selected && !state.loading) {
                state.loadChannels(source);
              }
            },
          );
        },
      ),
    );
  }

  // ---------- 搜索框 ----------

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(fontSize: 14, color: _textPrimary),
        decoration: InputDecoration(
          hintText: '搜索频道，如：CCTV、卫视…',
          prefixIcon: const Icon(Icons.search, size: 20, color: _textSecondary),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: _textSecondary),
                  onPressed: () => setState(() => _query = ''),
                ),
        ),
      ),
    );
  }

  // ---------- 主体 ----------

  Widget _buildBody(AppState state) {
    if (state.loading && state.channels.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _primary),
      );
    }
    if (state.loadError != null && state.channels.isEmpty) {
      return _buildError(state.loadError!);
    }
    if (state.channels.isEmpty) {
      return const Center(
        child: Text(
          '暂无频道，请选择上方直播源',
          style: TextStyle(fontSize: 14, color: _textSecondary),
        ),
      );
    }

    final query = _query.trim();
    if (query.isNotEmpty) {
      final results = AppState.search(state.channels, query);
      if (results.isEmpty) {
        return const Center(
          child: Text(
            '没有找到匹配的频道',
            style: TextStyle(fontSize: 14, color: _textSecondary),
          ),
        );
      }
      return _buildSearchResults(results);
    }
    return _buildGroupedList(state);
  }

  Widget _buildError(String message) {
    final state = AppScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Color(0xFF48484A)),
            const SizedBox(height: 12),
            const Text(
              '频道加载失败',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary),
            ),
            if (state.fallbackNote != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A2E14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.autorenew, size: 15, color: Color(0xFFFFC107)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        state.fallbackNote!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFFFD54F)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: _textSecondary),
            ),
            const SizedBox(height: 6),
            const Text(
              '请检查网络连接，或点击上方直播源切换其它源',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF48484A)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final s = state.activeSource ?? state.sources.firstOrNull;
                if (s != null) state.loadChannels(s);
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(List<Channel> results) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final channel = results[i];
        return _ChannelTile(
          channel: channel,
          onTap: () => _openPlayer(results, i),
        );
      },
    );
  }

  Widget _buildGroupedList(AppState state) {
    return RefreshIndicator(
      onRefresh: () async {
        final s = state.activeSource;
        if (s != null) await state.loadChannels(s);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (final group in state.groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Text(
                      group,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${state.channelsOf(group).length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final channels = state.channelsOf(group);
                    final channel = channels[i];
                    final flatIndex = state.channels.indexOf(channel);
                    return _ChannelTile(
                      channel: channel,
                      onTap: () => _openPlayer(state.channels, flatIndex),
                    );
                  },
                  childCount: state.channelsOf(group).length,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  void _openPlayer(List<Channel> channels, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(channels: channels, initialIndex: index),
      ),
    );
  }
}

/// 单个频道格子（Apple Music 风格：扁平 + 圆角台标封面）。
class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel, required this.onTap});

  final Channel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 圆角台标"封面"：近乎黑的深底 + 细描边，任何台标都有清晰轮廓
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF151517),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ChannelLogo(
              logoUrl: channel.logo,
              name: channel.name,
              size: 42,
            ),
          ),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFFE8E8ED),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
