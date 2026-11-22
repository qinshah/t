import 'package:flutter/material.dart';
import 'package:panes/panes.dart';
import 'package:provider/provider.dart';

import 'features/settings/providers/settings_provider.dart';
import 'features/terminal/screens/terminal_screen.dart';

/// 根 Navigator，供没有 [BuildContext] 的入口（如 macOS 应用菜单）打开对话框。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// 应用根组件。
///
/// 终端区域由 ghostty_dart_flutter 自绘，其余界面使用 Material 组件。
class TerminalApp extends StatelessWidget {
  const TerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 't',
          navigatorKey: rootNavigatorKey,
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: settings.themeMode,
          home: const TerminalScreen(),
        );
      },
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2DD4BF),
    brightness: brightness,
  );
  final dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0E1116)
        : const Color(0xFFF5F6F8),
    // 侧边栏分隔条跟随主题，避免浅色模式下还是一条深色线。
    extensions: [
      PaneThemeData(
        resizerColor: scheme.outlineVariant.withValues(alpha: 0.55),
        resizerHoverColor: scheme.primary,
        resizerFocusedColor: scheme.primary,
        resizerThickness: 1,
      ),
    ],
  );
}
