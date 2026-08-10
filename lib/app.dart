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

  ThemeData _buildTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE53935),
        brightness: Brightness.dark,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1A1A),
        indicatorColor: const Color(0xFFE53935),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1F1F1F),
        elevation: 0,
      ),
    );
  }
}
