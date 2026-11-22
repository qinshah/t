import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';
import 'package:ghostty_dart_flutter/ghostty_dart_flutter.dart'
    show VtTerminalTheme;

/// Solarized 终端配色。
///
/// 16 色沿用 Solarized 官方色号；浅色背景 `base3`、深色背景 `base03`。
/// 搜索高亮沿用上游默认值，只跟终端配色无关。
abstract final class SolarizedThemes {
  /// 按亮度取对应的一套色板。
  static VtTerminalTheme of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Solarized Light：浅米色背景，默认配色。
  static const light = VtTerminalTheme(
    cursor: Color(0xFF586E75),
    selection: Color(0x6693A1A1),
    foreground: Color(0xFF657B83),
    background: Color(0xFFFDF6E3),
    black: Color(0xFF073642),
    red: Color(0xFFDC322F),
    green: Color(0xFF859900),
    yellow: Color(0xFFB58900),
    blue: Color(0xFF268BD2),
    magenta: Color(0xFFD33682),
    cyan: Color(0xFF2AA198),
    white: Color(0xFFEEE8D5),
    brightBlack: Color(0xFF002B36),
    brightRed: Color(0xFFCB4B16),
    brightGreen: Color(0xFF586E75),
    brightYellow: Color(0xFF657B83),
    brightBlue: Color(0xFF839496),
    brightMagenta: Color(0xFF6C71C4),
    brightCyan: Color(0xFF93A1A1),
    brightWhite: Color(0xFFFDF6E3),
    searchHitBackground: Color(0xFFFFFF2B),
    searchHitBackgroundCurrent: Color(0xFF31FF26),
    searchHitForeground: Color(0xFF000000),
  );

  /// Solarized Dark：深蓝背景，与 [light] 使用同一套 16 色。
  static const dark = VtTerminalTheme(
    cursor: Color(0xFF93A1A1),
    selection: Color(0x6693A1A1),
    foreground: Color(0xFF839496),
    background: Color(0xFF002B36),
    black: Color(0xFF073642),
    red: Color(0xFFDC322F),
    green: Color(0xFF859900),
    yellow: Color(0xFFB58900),
    blue: Color(0xFF268BD2),
    magenta: Color(0xFFD33682),
    cyan: Color(0xFF2AA198),
    white: Color(0xFFEEE8D5),
    brightBlack: Color(0xFF002B36),
    brightRed: Color(0xFFCB4B16),
    brightGreen: Color(0xFF586E75),
    brightYellow: Color(0xFF657B83),
    brightBlue: Color(0xFF839496),
    brightMagenta: Color(0xFF6C71C4),
    brightCyan: Color(0xFF93A1A1),
    brightWhite: Color(0xFFFDF6E3),
    searchHitBackground: Color(0xFFFFFF2B),
    searchHitBackgroundCurrent: Color(0xFF31FF26),
    searchHitForeground: Color(0xFF000000),
  );
}
