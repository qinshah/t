import 'package:flutter/material.dart';

import 'features/terminal/screens/terminal_screen.dart';

/// 应用根组件。
///
/// 终端区域由 ghostty_dart_flutter 自绘，其余界面使用 Material 组件。
class TerminalApp extends StatelessWidget {
  const TerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 't',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.dark),
      home: const TerminalScreen(),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2DD4BF),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0E1116),
  );
}
