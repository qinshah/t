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
/// 终端字号是例外：它会被滚轮/手势高频修改，内存值由本类持有，落盘用
/// 5 秒防抖（见 [setTerminalFontSize]）。
class SettingsProvider extends ChangeNotifier {
  /// 当前终端字号；启动时从偏好读取，运行中即时更新内存，落盘延迟见
  /// [_scheduleFontSizeWrite]。
  late int _terminalFontSize = _clampFontSize(Setting.terminalFontSize.get());

  /// 字号变化的延迟落盘定时器；每次变化都重置，只有停下来 5 秒才写入。
  Timer? _fontSizeWriteTimer;

  /// 停止调整多久后把字号写入偏好文件。
  static const Duration _fontSizeWriteDelay = Duration(seconds: 5);

  static int _clampFontSize(int value) =>
      value.clamp(minTerminalFontSize, maxTerminalFontSize).toInt();

  /// 界面深浅色模式。
  ThemeMode get themeMode => Setting.themeMode.get();

  /// 终端配色深浅；自动时跟随应用主题亮度。
  ThemeMode get terminalThemeMode => Setting.terminalThemeMode.get();

  /// 终端字号。
  int get terminalFontSize => _terminalFontSize;

  /// 关闭最后一个终端后是否退出应用。
  bool get quitWhenLastClosed => Setting.quitWhenLastClosed.get();

  /// 界面模式是否仍为默认。
  bool get isThemeModeDefault => Setting.themeMode.isDefault;

  /// 终端模式是否仍为默认。
  bool get isTerminalThemeModeDefault => Setting.terminalThemeMode.isDefault;

  /// 终端字号是否仍为默认。
  bool get isTerminalFontSizeDefault =>
      _terminalFontSize == defaultTerminalFontSize;

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

  /// 设置终端字号；超出范围会被夹到 4–64。
  ///
  /// 界面立即更新，偏好文件延迟到用户停止调整 5 秒后写入，
  /// 避免滚轮/缩放过程中频繁落盘。
  void setTerminalFontSize(int value) {
    final next = _clampFontSize(value);
    if (next == _terminalFontSize) return;
    _terminalFontSize = next;
    notifyListeners();
    _scheduleFontSizeWrite();
  }

  /// 放大一级。
  void zoomIn() => setTerminalFontSize(_terminalFontSize + 1);

  /// 缩小一级。
  void zoomOut() => setTerminalFontSize(_terminalFontSize - 1);

  /// 字号恢复默认；同样走延迟写入。
  void resetTerminalFontSize() => setTerminalFontSize(defaultTerminalFontSize);

  /// 立即写入还没落盘的字号；应用退出前调用，避免丢掉最后 5 秒内的修改。
  Future<void> flushTerminalFontSize() {
    final timer = _fontSizeWriteTimer;
    if (timer == null) return Future<void>.value();
    timer.cancel();
    _fontSizeWriteTimer = null;
    return Setting.terminalFontSize.set(_terminalFontSize);
  }

  /// 每次修改都重置定时器：只有停止操作 5 秒才真正写入。
  void _scheduleFontSizeWrite() {
    _fontSizeWriteTimer?.cancel();
    _fontSizeWriteTimer = Timer(_fontSizeWriteDelay, () {
      _fontSizeWriteTimer = null;
      unawaited(Setting.terminalFontSize.set(_terminalFontSize));
    });
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

  @override
  void dispose() {
    _fontSizeWriteTimer?.cancel();
    _fontSizeWriteTimer = null;
    super.dispose();
  }
}
