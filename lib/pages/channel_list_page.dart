import 'package:flutter/material.dart';

import '../app.dart';
import '../models/channel.dart';
import '../state/app_state.dart';
import '../widgets/channel_logo.dart';
import 'player_page.dart';

/// 直播频道列表页。
class ChannelListPage extends StatefulWidget {
  const ChannelListPage({super.key});

  @override
  State<ChannelListPage> createState() => _ChannelListPageState();
}

class _ChannelListPageState extends State<ChannelListPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
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
      ),
      body: Column(
        children: [
          _buildSourceBar(state),
          if (state.loading) const LinearProgressIndicator(minHeight: 2),
          _buildSearchBar(),
          Expanded(child: _buildBody(state)),
        ],
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
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
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
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: '搜索频道，如：CCTV、卫视…',
          hintStyle: TextStyle(fontSize: 14, color: Colors.white38),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() => _query = ''),
                ),
          isDense: true,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ---------- 主体 ----------

  Widget _buildBody(AppState state) {
    if (state.loading && state.channels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.loadError != null && state.channels.isEmpty) {
      return _buildError(state.loadError!);
    }
    if (state.channels.isEmpty) {
      return const Center(child: Text('暂无频道，请选择上方直播源'));
    }

    final query = _query.trim();
    if (query.isNotEmpty) {
      final results = AppState.search(state.channels, query);
      if (results.isEmpty) {
        return const Center(child: Text('没有找到匹配的频道'));
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
            const Icon(Icons.cloud_off, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              '频道加载失败',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (state.fallbackNote != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A2E10),
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
              style: const TextStyle(fontSize: 12.5, color: Colors.white54),
            ),
            const SizedBox(height: 6),
            const Text(
              '请检查网络连接，或点击上方直播源切换其它源',
              style: TextStyle(fontSize: 11.5, color: Colors.white38),
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
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
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
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      group,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${state.channelsOf(group).length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
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
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
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

/// 单个频道格子。
class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel, required this.onTap});

  final Channel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ChannelLogo(logoUrl: channel.logo, name: channel.name, size: 52),
          const SizedBox(height: 6),
          Text(
            channel.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
