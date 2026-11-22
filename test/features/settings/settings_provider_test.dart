import 'dart:ui' show Brightness;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:t/features/settings/models/setting.dart';
import 'package:t/features/settings/models/solarized_themes.dart';
import 'package:t/features/settings/providers/settings_provider.dart';
import 'package:t/features/settings/services/settings_store.dart';

void main() {
  late SettingsProvider settings;

  setUp(() {
    Setting.store = SettingsStore.memory();
    settings = SettingsProvider();
  });

  tearDown(() {
    settings.dispose();
  });

  group('SettingsProvider.terminalThemeFor', () {
    test('默认自动跟随应用主题亮度', () {
      expect(settings.terminalThemeMode, ThemeMode.system);
      expect(settings.terminalThemeFor(Brightness.dark), SolarizedThemes.dark);
      expect(
        settings.terminalThemeFor(Brightness.light),
        SolarizedThemes.light,
      );
    });

    test('暗色 / 亮色强制覆盖应用亮度', () {
      settings.setTerminalThemeMode(ThemeMode.dark);
      expect(settings.terminalThemeFor(Brightness.light), SolarizedThemes.dark);

      settings.setTerminalThemeMode(ThemeMode.light);
      expect(settings.terminalThemeFor(Brightness.dark), SolarizedThemes.light);
    });

    test('恢复默认后重新跟随应用主题', () {
      settings.setTerminalThemeMode(ThemeMode.dark);
      expect(settings.isTerminalThemeModeDefault, isFalse);

      settings.resetTerminalThemeMode();
      expect(settings.isTerminalThemeModeDefault, isTrue);
      expect(
        settings.terminalThemeFor(Brightness.light),
        SolarizedThemes.light,
      );
    });
  });

  group('SettingsProvider 其他偏好', () {
    test('界面模式映射 ThemeMode', () {
      expect(settings.themeMode, ThemeMode.system);
      settings.setThemeMode(ThemeMode.dark);
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.isThemeModeDefault, isFalse);
    });

    test('自动退出默认开启，可修改与恢复', () {
      expect(settings.quitWhenLastClosed, isTrue);

      settings.setQuitWhenLastClosed(false);
      expect(settings.quitWhenLastClosed, isFalse);
      expect(settings.isQuitWhenLastClosedDefault, isFalse);

      settings.resetQuitWhenLastClosed();
      expect(settings.quitWhenLastClosed, isTrue);
      expect(settings.isQuitWhenLastClosedDefault, isTrue);
    });
  });
}
