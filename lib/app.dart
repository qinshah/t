import 'dart:io';

import 'package:flutter/material.dart';
import 'package:panes/panes.dart';
import 'package:provider/provider.dart';

import 'features/settings/providers/settings_provider.dart';
import 'features/terminal/providers/terminal_tabs_provider.dart';
import 'features/terminal/screens/terminal_screen.dart';

/// 根 Navigator，供没有 [BuildContext] 的入口（如 macOS 应用菜单）打开对话框。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// 应用根组件。
///
/// 终端区域由 ghostty_dart_flutter 自绘，其余界面使用 Material 组件。
class TerminalApp extends StatefulWidget {
  const TerminalApp({super.key});

  @override
  State<TerminalApp> createState() => _TerminalAppState();
}

class _TerminalAppState extends State<TerminalApp> {
  late final SettingsProvider _settings;
  late final TerminalTabsProvider _tabs;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>();
    _tabs = TerminalTabsProvider(
      theme: _settings.terminalThemeFor(_resolvedBrightness()),
      // 关闭最后一个终端后，按偏好决定是否退出应用。
      onLastTabClosed: () {
        if (_settings.quitWhenLastClosed) exit(0);
      },
    );
  }

  /// 应用主题解析后的亮度：固定深浅时取设置，自动时取系统亮度。
  Brightness _resolvedBrightness() => switch (_settings.themeMode) {
    ThemeMode.dark => Brightness.dark,
    ThemeMode.light => Brightness.light,
    ThemeMode.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
  };

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        // provider 放在 MaterialApp 之上，设置等覆盖层路由也能拿到标签状态。
        return ChangeNotifierProvider<TerminalTabsProvider>.value(
          value: _tabs,
          child: MaterialApp(
            title: 't',
            navigatorKey: rootNavigatorKey,
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            themeMode: settings.themeMode,
            home: const TerminalScreen(),
          ),
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
