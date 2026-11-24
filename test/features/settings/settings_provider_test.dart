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

  group('SettingsProvider 终端字号', () {
    test('默认 16，缩放步进 1 并限制在 4–64', () {
      expect(settings.terminalFontSize, defaultTerminalFontSize);
      expect(settings.isTerminalFontSizeDefault, isTrue);

      settings.zoomIn();
      expect(settings.terminalFontSize, defaultTerminalFontSize + 1);
      settings.zoomOut();
      settings.zoomOut();
      expect(settings.terminalFontSize, defaultTerminalFontSize - 1);

      settings.setTerminalFontSize(maxTerminalFontSize + 20);
      expect(settings.terminalFontSize, maxTerminalFontSize);
      settings.zoomIn();
      expect(settings.terminalFontSize, maxTerminalFontSize);

      settings.setTerminalFontSize(minTerminalFontSize - 20);
      expect(settings.terminalFontSize, minTerminalFontSize);
      settings.zoomOut();
      expect(settings.terminalFontSize, minTerminalFontSize);
    });

    test('读取时夹到允许范围', () async {
      await Setting.store.put('terminalFontSize', 999);
      final clamped = SettingsProvider();
      addTearDown(clamped.dispose);
      expect(clamped.terminalFontSize, maxTerminalFontSize);
    });

    test('恢复默认回到 16', () {
      settings.setTerminalFontSize(30);
      expect(settings.isTerminalFontSizeDefault, isFalse);

      settings.resetTerminalFontSize();
      expect(settings.terminalFontSize, defaultTerminalFontSize);
      expect(settings.isTerminalFontSizeDefault, isTrue);
    });

    testWidgets('修改后延迟 5 秒写入，期间只更新内存值', (tester) async {
      settings.setTerminalFontSize(20);
      expect(settings.terminalFontSize, 20);
      expect(Setting.store.get<num>('terminalFontSize'), isNull);

      // 4 秒时还没到点；第 5 秒才真正落盘。
      await tester.pump(const Duration(seconds: 4));
      expect(Setting.store.get<num>('terminalFontSize'), isNull);

      await tester.pump(const Duration(seconds: 1));
      expect(Setting.store.get<num>('terminalFontSize'), 20);
    });

    testWidgets('连续修改会重置定时器', (tester) async {
      settings.setTerminalFontSize(18);
      await tester.pump(const Duration(seconds: 3));

      settings.setTerminalFontSize(22);
      await tester.pump(const Duration(seconds: 3));
      // 距离第二次修改才 3 秒，仍未写入。
      expect(Setting.store.get<num>('terminalFontSize'), isNull);

      await tester.pump(const Duration(seconds: 2));
      expect(Setting.store.get<num>('terminalFontSize'), 22);
    });

    test('flush 立即写入待保存的字号', () async {
      settings.setTerminalFontSize(28);
      expect(Setting.store.get<num>('terminalFontSize'), isNull);

      await settings.flushTerminalFontSize();
      expect(Setting.store.get<num>('terminalFontSize'), 28);
    });
  });
}
