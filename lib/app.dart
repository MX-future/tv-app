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

  /// Apple Music 风格深色主题：近纯黑背景 + 亮红点缀 + 扁平层次。
  ThemeData _buildTheme() {
    const bg = Color(0xFF0A0A0C);
    const surface = Color(0xFF1C1C1E);
    const elevated = Color(0xFF2C2C2E);
    const primary = Color(0xFFFA2D48); // Apple Music 红
    const textMain = Color(0xFFFFFFFF);
    const textSub = Color(0xFF98989D);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: surface,
      primary: primary,
      onPrimary: Colors.white,
      onSurface: textMain,
      onSurfaceVariant: textSub,
      outline: const Color(0xFF48484A),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      // ---------- AppBar：透明，由 flexibleSpace 玻璃层提供视觉 ----------
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: textMain,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: textMain),
      ),
      // ---------- 底部导航：透明，由外层 GlassBox 提供视觉 ----------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.2),
        elevation: 0,
        height: 62,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : textSub,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? textMain : textSub,
          ),
        ),
      ),
      // ---------- 卡片：扁平深灰（Apple Music 分组列表感） ----------
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      // ---------- 弹窗：深灰大圆角 ----------
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          color: textMain,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: textSub,
          fontSize: 14,
          height: 1.55,
        ),
      ),
      // ---------- 输入框：胶囊形 ----------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF6E6E73)),
      ),
      // ---------- 列表 ----------
      listTileTheme: const ListTileThemeData(
        iconColor: textSub,
        textColor: textMain,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: elevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: primary.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide.none,
        labelStyle: const TextStyle(fontSize: 12.5, color: textSub),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
    );
  }
}

/// 毛玻璃 AppBar 背景（Apple Music 风格：近纯黑玻璃 + 状态栏安全区）。
class GlassAppBarBackdrop extends StatelessWidget {
  const GlassAppBarBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      sigma: 24,
      color: const Color(0xFF0A0A0C),
      alpha: 0.5,
      child: Column(
        children: [
          Container(
            height: MediaQuery.paddingOf(context).top,
            color: const Color(0xFF0A0A0C).withValues(alpha: 0.96),
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
    this.sigma = 24,
    this.color = const Color(0xFF0A0A0C),
    this.alpha = 0.5,
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
