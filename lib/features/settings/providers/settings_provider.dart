import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ghostty_dart_flutter/ghostty_dart_flutter.dart'
    show VtTerminalTheme;

import '../models/app_preferences.dart';
import '../models/solarized_themes.dart';
import '../services/preferences_store.dart';

/// 应用级偏好的状态与持久化入口。
///
/// 修改先更新内存并 `notifyListeners`（界面立即生效），随后异步落盘；
/// 读取与写入的异常由 [PreferencesStore] 内部消化。
class SettingsProvider extends ChangeNotifier {
  /// 创建 provider。
  ///
  /// [initial] 由 `main` 在启动时从磁盘读取，避免首帧闪默认主题。
  SettingsProvider({
    required PreferencesStore store,
    required AppPreferences initial,
  }) : this._(store, initial);

  SettingsProvider._(this._store, this._preferences);

  final PreferencesStore _store;
  AppPreferences _preferences;

  /// 当前颜色模式。
  AppColorMode get colorMode => _preferences.colorMode;

  /// 当前终端配色预制。
  TerminalPalette get terminalPalette => _preferences.terminalPalette;

  /// 当前终端配色深浅。
  TerminalBrightness get terminalBrightness => _preferences.terminalBrightness;

  /// 映射到 `MaterialApp.themeMode`。
  ThemeMode get themeMode => switch (colorMode) {
    AppColorMode.auto => ThemeMode.system,
    AppColorMode.dark => ThemeMode.dark,
    AppColorMode.light => ThemeMode.light,
  };

  /// 按当前偏好与**应用主题**亮度决定终端用哪套色板。
  ///
  /// [appBrightness] 是当前 `Theme.of(context).brightness`，也就是
  /// MaterialApp 解析 `themeMode` 之后实际使用的深浅色。
  /// `随颜色` 直接跟随它，另外两档强制深浅。
  VtTerminalTheme terminalThemeFor(Brightness appBrightness) {
    final brightness = switch (terminalBrightness) {
      TerminalBrightness.followColorMode => appBrightness,
      TerminalBrightness.dark => Brightness.dark,
      TerminalBrightness.light => Brightness.light,
    };
    return SolarizedThemes.of(brightness);
  }

  /// 颜色模式是否仍为默认值。
  bool get isColorModeDefault => colorMode == AppDefaults.colorMode;

  /// 终端配色是否仍为默认值。
  bool get isTerminalPaletteDefault =>
      terminalPalette == AppDefaults.terminalPalette;

  /// 终端深浅是否仍为默认值。
  bool get isTerminalBrightnessDefault =>
      terminalBrightness == AppDefaults.terminalBrightness;

  /// 修改颜色模式并立即生效。
  void setColorMode(AppColorMode mode) {
    if (mode == colorMode) return;
    _update(_preferences.copyWith(colorMode: mode));
  }

  /// 修改终端配色并立即生效。
  void setTerminalPalette(TerminalPalette palette) {
    if (palette == terminalPalette) return;
    _update(_preferences.copyWith(terminalPalette: palette));
  }

  /// 修改终端配色深浅并立即生效。
  void setTerminalBrightness(TerminalBrightness brightness) {
    if (brightness == terminalBrightness) return;
    _update(_preferences.copyWith(terminalBrightness: brightness));
  }

  /// 颜色模式恢复默认。
  void resetColorMode() => setColorMode(AppDefaults.colorMode);

  /// 终端配色恢复默认。
  void resetTerminalPalette() =>
      setTerminalPalette(AppDefaults.terminalPalette);

  /// 终端深浅恢复默认。
  void resetTerminalBrightness() =>
      setTerminalBrightness(AppDefaults.terminalBrightness);

  void _update(AppPreferences next) {
    _preferences = next;
    notifyListeners();
    unawaited(_store.save(next));
  }
}
