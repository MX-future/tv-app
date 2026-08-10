import 'dart:ui';

import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'state/app_state.dart';

/// 全局状态作用域（InheritedNotifier）。
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState super.notifier,
    required super.child,
  });

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}

/// 应用根组件。
class TvApp extends StatefulWidget {
  const TvApp({super.key});

  @override
  State<TvApp> createState() => _TvAppState();
}

class _TvAppState extends State<TvApp> {
  final AppState _state = AppState();

  @override
  void initState() {
    super.initState();
    _state.init();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: _state,
      child: MaterialApp(
        title: '电视直播',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const HomePage(),
      ),
    );
  }

  /// 清爽浅色主题：白底 + 浅灰层次 + 品牌红点缀 + 毛玻璃。
  ThemeData _buildTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE53935),
      brightness: Brightness.light,
      surface: const Color(0xFFF6F7F9),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      // ---------- AppBar：毛玻璃（透明底，由 flexibleSpace 玻璃层提供视觉） ----------
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      // ---------- 底部导航：毛玻璃（透明底，由外层 GlassBox 提供视觉） ----------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        elevation: 0,
        height: 66,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ),
      // ---------- 卡片：纯白 + 细边 + 大圆角 ----------
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // ---------- 弹窗：统一白色大圆角 ----------
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
          height: 1.55,
        ),
      ),
      // ---------- 输入框 ----------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.85),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      // ---------- 列表 ----------
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2B2B2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.05),
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
    );
  }
}

/// 毛玻璃背景组件（BackdropFilter 高斯模糊）。
class GlassBox extends StatelessWidget {
  const GlassBox({
    super.key,
    this.sigma = 18,
    this.color = Colors.white,
    this.alpha = 0.62,
    this.borderRadius,
    this.border,
    this.child,
  });

  /// 模糊强度
  final double sigma;

  /// 背景颜色
  final Color color;

  /// 背景不透明度
  final double alpha;

  final BorderRadius? borderRadius;
  final Border? border;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Widget inner = Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: borderRadius,
        border: border,
      ),
      child: child,
    );
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: inner,
      ),
    );
  }
}
