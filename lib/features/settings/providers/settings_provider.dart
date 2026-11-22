import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ghostty_dart_flutter/ghostty_dart_flutter.dart'
    show VtTerminalTheme;

import '../models/setting.dart';
import '../models/solarized_themes.dart';

/// 应用级偏好的状态入口。
///
/// 值本身由 [Setting] 的静态实例持有并直接落盘；这里负责在修改后通知
/// 界面重建，并把偏好翻译成 `MaterialApp` / 终端需要的类型。
class SettingsProvider extends ChangeNotifier {
  /// 界面深浅色模式。
  ThemeMode get themeMode => Setting.themeMode.get();

  /// 终端配色深浅；自动时跟随应用主题亮度。
  ThemeMode get terminalThemeMode => Setting.terminalThemeMode.get();

  /// 关闭最后一个终端后是否退出应用。
  bool get quitWhenLastClosed => Setting.quitWhenLastClosed.get();

  /// 界面模式是否仍为默认。
  bool get isThemeModeDefault => Setting.themeMode.isDefault;

  /// 终端模式是否仍为默认。
  bool get isTerminalThemeModeDefault => Setting.terminalThemeMode.isDefault;

  /// 自动退出是否仍为默认。
  bool get isQuitWhenLastClosedDefault => Setting.quitWhenLastClosed.isDefault;

  /// 按终端偏好与**应用主题**亮度决定终端用哪套色板。
  ///
  /// [appBrightness] 是当前 `Theme.of(context).brightness`，也就是
  /// MaterialApp 解析 `themeMode` 之后实际使用的深浅色。
  /// 自动模式直接跟随它，暗色 / 亮色则强制覆盖。
  VtTerminalTheme terminalThemeFor(Brightness appBrightness) {
    final brightness = switch (terminalThemeMode) {
      ThemeMode.system => appBrightness,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
    };
    return SolarizedThemes.of(brightness);
  }

  /// 修改界面深浅色模式。
  void setThemeMode(ThemeMode mode) {
    if (mode == themeMode) return;
    unawaited(Setting.themeMode.set(mode));
    notifyListeners();
  }

  /// 修改终端深浅色模式。
  void setTerminalThemeMode(ThemeMode mode) {
    if (mode == terminalThemeMode) return;
    unawaited(Setting.terminalThemeMode.set(mode));
    notifyListeners();
  }

  /// 修改「关闭最后一个终端后自动退出」。
  void setQuitWhenLastClosed(bool value) {
    if (value == quitWhenLastClosed) return;
    unawaited(Setting.quitWhenLastClosed.set(value));
    notifyListeners();
  }

  /// 界面模式恢复默认。
  void resetThemeMode() => _reset(Setting.themeMode);

  /// 终端模式恢复默认。
  void resetTerminalThemeMode() => _reset(Setting.terminalThemeMode);

  /// 自动退出恢复默认。
  void resetQuitWhenLastClosed() => _reset(Setting.quitWhenLastClosed);

  void _reset(Setting<dynamic, dynamic> setting) {
    unawaited(setting.reset());
    notifyListeners();
  }
}
