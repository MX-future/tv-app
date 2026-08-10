import 'package:flutter/material.dart';

/// 频道台标组件：加载 tvg-logo，失败时自动尝试镜像域名，最终显示文字占位。
///
/// 台标使用 `BoxFit.contain` 完整显示（不裁切台标内文字），
/// 文字占位通过 `FittedBox` 自适应缩放，保证永不溢出截断。
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
    final scheme = Theme.of(context).colorScheme;
    if (_urls.isEmpty || _urlIndex >= _urls.length) {
      return _placeholder(context);
    }
    final url = _urls[_urlIndex];
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        width: widget.size,
        height: widget.size,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Image.network(
          url,
          width: widget.size,
          height: widget.size,
          // 完整显示台标，避免 cover 裁掉台标中的文字
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) {
            // 当前地址加载失败：尝试下一个候选地址
            if (_urlIndex < _urls.length - 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _urlIndex++);
              });
            }
            return _placeholder(context);
          },
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = widget.name.trim();
    // 展示名称末尾 1~2 个字，短名放大、长名缩小
    final short = name.length >= 2 ? name.substring(name.length - 2) : name;
    final fontSize = short.length <= 1 ? widget.size * 0.3 : widget.size * 0.24;
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      padding: EdgeInsets.all(widget.size * 0.1),
      // FittedBox 保证文字始终完整显示，不被截断
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          short,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
