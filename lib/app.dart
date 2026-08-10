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

  /// 深炭黑主题：带蓝调的深色层次 + 品牌红点缀 + 深色毛玻璃。
  ThemeData _buildTheme() {
    const bg = Color(0xFF0F1216);
    const surface = Color(0xFF1A1E25);
    const primary = Color(0xFFE53935);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: surface,
      primary: primary,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      // ---------- AppBar：透明底，由 flexibleSpace 玻璃层提供视觉 ----------
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Color(0xFFF2F5F9),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF2F5F9)),
      ),
      // ---------- 底部导航：透明底，由外层 GlassBox 提供视觉 ----------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.2),
        elevation: 0,
        height: 66,
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ),
      // ---------- 卡片：深灰 + 1px 细描边（替代阴影，更精致） ----------
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      // ---------- 弹窗：深色玻璃大圆角 ----------
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF20242D),
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        titleTextStyle: const TextStyle(
          color: Color(0xFFF2F5F9),
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFFB6BEC9),
          fontSize: 14,
          height: 1.55,
        ),
      ),
      // ---------- 输入框 ----------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1E25),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
      ),
      // ---------- 列表 ----------
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF8E98A6),
        textColor: Color(0xFFF2F5F9),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2F39),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.05),
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFF1A1E25),
        selectedColor: primary.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFD6DCE4)),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFF6B66),
        ),
      ),
    );
  }
}

/// 毛玻璃 AppBar 背景：整体深色玻璃，状态栏安全区用高不透明白保证图标清晰。
class GlassAppBarBackdrop extends StatelessWidget {
  const GlassAppBarBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      sigma: 22,
      color: const Color(0xFF171B22),
      alpha: 0.62,
      child: Column(
        children: [
          // 状态栏安全区：较实，避免毛玻璃透出内容干扰状态栏图标
          Container(
            height: MediaQuery.paddingOf(context).top,
            color: const Color(0xFF0F1216).withValues(alpha: 0.95),
          ),
          const Expanded(child: SizedBox.expand()),
        ],
      ),
    );
  }
}

/// 毛玻璃背景组件（BackdropFilter 高斯模糊）。
class GlassBox extends StatelessWidget {
  const GlassBox({
    super.key,
    this.sigma = 22,
    this.color = const Color(0xFF171B22),
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
