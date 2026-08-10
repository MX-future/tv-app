import 'package:flutter/material.dart';

/// 频道台标组件：加载 tvg-logo，失败时自动尝试镜像域名，最终显示文字占位。
class ChannelLogo extends StatefulWidget {
  const ChannelLogo({
    super.key,
    this.logoUrl,
    required this.name,
    this.size = 44,
    this.borderRadius = 8,
  });

  final String? logoUrl;
  final String name;
  final double size;
  final double borderRadius;

  @override
  State<ChannelLogo> createState() => _ChannelLogoState();
}

class _ChannelLogoState extends State<ChannelLogo> {
  List<String> _urls = [];
  int _urlIndex = 0;

  @override
  void initState() {
    super.initState();
    _urls = _buildCandidates(widget.logoUrl);
  }

  @override
  void didUpdateWidget(covariant ChannelLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logoUrl != widget.logoUrl) {
      _urls = _buildCandidates(widget.logoUrl);
      _urlIndex = 0;
    }
  }

  /// 生成台标候选地址：原始地址 → raw.githubusercontent → com 域名。
  static List<String> _buildCandidates(String? logoUrl) {
    if (logoUrl == null || logoUrl.isEmpty) return const [];
    final list = <String>[logoUrl];
    final match = RegExp(r'/tv/([^/?#]+\.(?:png|jpg|jpeg))').firstMatch(logoUrl);
    if (match != null) {
      final file = match.group(1)!;
      const mirrors = [
        'https://raw.githubusercontent.com/fanmingming/live/main/tv/',
        'https://live.fanmingming.com/tv/',
      ];
      for (final m in mirrors) {
        final alt = '$m$file';
        if (alt != logoUrl && !list.contains(alt)) list.add(alt);
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty || _urlIndex >= _urls.length) {
      return _placeholder(context);
    }
    final url = _urls[_urlIndex];
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.network(
        url,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          // 当前地址加载失败：尝试下一个候选地址
          if (_urlIndex < _urls.length - 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _urlIndex++);
            });
            // 返回占位避免空白闪烁
            return _placeholder(context);
          }
          return _placeholder(context);
        },
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final short = widget.name.length >= 2
        ? widget.name.substring(widget.name.length - 2)
        : widget.name;
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Text(
        short,
        style: TextStyle(
          fontSize: widget.size * 0.26,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
