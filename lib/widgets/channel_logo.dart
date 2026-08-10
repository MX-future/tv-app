import 'package:flutter/material.dart';

/// 频道台标组件：加载 tvg-logo，失败时显示文字占位。
class ChannelLogo extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final url = logoUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(context),
        ),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final short = name.length >= 2 ? name.substring(name.length - 2) : name;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        short,
        style: TextStyle(
          fontSize: size * 0.26,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
