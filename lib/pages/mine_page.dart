import 'package:flutter/material.dart';

import '../app.dart';
import '../models/play_source.dart';
import '../state/app_state.dart';

/// "我的"页：直播源管理与设置（清爽浅色风格）。
class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final topPad = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('我的'),
        flexibleSpace: GlassBox(
          sigma: 18,
          color: Colors.white,
          alpha: 0.55,
          child: const SizedBox.expand(),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.only(top: topPad),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _sectionTitle(context, '直播源'),
            const SizedBox(height: 4),
            _buildSources(context, state),
            const SizedBox(height: 20),
            _sectionTitle(context, '设置'),
            _buildSettings(context, state),
            const SizedBox(height: 20),
            _sectionTitle(context, '关于'),
            _buildAbout(context),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSources(BuildContext context, AppState state) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final source in state.sources) _sourceTile(context, state, source),
          ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.add,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: const Text('添加自定义源', style: TextStyle(fontSize: 14)),
            onTap: () => _showAddSourceDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _sourceTile(BuildContext context, AppState state, PlaySource source) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final selected = state.activeSource?.id == source.id;
    return ListTile(
      dense: true,
      leading: Icon(
        source.builtIn ? Icons.cloud_done_outlined : Icons.link,
        size: 20,
        color: selected ? primary : scheme.onSurfaceVariant,
      ),
      title: Text(
        source.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected ? primary : scheme.onSurface,
        ),
      ),
      subtitle: Text(
        source.url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: scheme.outline),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.loading && selected)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (!source.builtIn)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 19, color: scheme.outline),
              onPressed: () => state.removeSource(source),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
      onTap: () {
        if (!selected && !state.loading) {
          state.loadChannels(source);
        }
      },
    );
  }

  Future<void> _showAddSourceDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final state = AppScope.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加直播源'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '名称（可选）',
                  hintText: '如：我的源',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: urlCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '订阅地址',
                  hintText: 'https://.../playlist.m3u 或 .txt',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入订阅地址';
                  if (!v.trim().startsWith('http')) return '地址需以 http(s) 开头';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await state.addCustomSource(nameCtrl.text, urlCtrl.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加，点击该源即可加载频道')),
        );
      }
    }
  }

  Widget _buildSettings(BuildContext context, AppState state) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.brightness_high_outlined, size: 20),
            title: const Text('播放时保持屏幕常亮', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              '全屏观看直播时不自动息屏',
              style: TextStyle(fontSize: 11.5, color: Colors.black45),
            ),
            value: state.keepScreenOn,
            onChanged: state.setKeepScreenOn,
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.wifi_outlined, size: 20),
            title: const Text('仅 WiFi 下播放', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              '使用移动数据播放时弹窗确认，防止流量消耗',
              style: TextStyle(fontSize: 11.5, color: Colors.black45),
            ),
            value: state.wifiOnly,
            onChanged: state.setWifiOnly,
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.favorite_border, size: 20),
            title: const Text('清空最近播放记录', style: TextStyle(fontSize: 14)),
            onTap: () async {
              await state.clearRecent();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已清空')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAbout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '电视直播 v1.0.8',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '直播源来自 best-fan/iptv-sources 开源项目（github.com/best-fan/iptv-sources），'
              '每日自动检测有效性，频道与 EPG 数据均为互联网公开资源，仅供个人测试学习使用。',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
