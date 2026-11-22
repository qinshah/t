import 'dart:io';
import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:t/features/settings/models/app_preferences.dart';
import 'package:t/features/settings/models/solarized_themes.dart';
import 'package:t/features/settings/providers/settings_provider.dart';
import 'package:t/features/settings/services/preferences_store.dart';

void main() {
  late Directory directory;
  late PreferencesStore store;
  late SettingsProvider settings;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('t_settings_provider');
    store = PreferencesStore(directoryProvider: () async => directory);
    settings = SettingsProvider(store: store, initial: const AppPreferences());
  });

  tearDown(() async {
    // 先等异步落盘结束，再删临时目录，避免删除与写入竞争。
    await store.flush();
    settings.dispose();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  group('SettingsProvider.terminalThemeFor', () {
    test('默认「随颜色」跟随应用主题亮度', () {
      expect(settings.terminalBrightness, TerminalBrightness.followColorMode);
      expect(settings.terminalThemeFor(Brightness.dark), SolarizedThemes.dark);
      expect(
        settings.terminalThemeFor(Brightness.light),
        SolarizedThemes.light,
      );
    });

    test('深色 / 浅色强制覆盖应用亮度', () {
      settings.setTerminalBrightness(TerminalBrightness.dark);
      expect(settings.terminalThemeFor(Brightness.light), SolarizedThemes.dark);

      settings.setTerminalBrightness(TerminalBrightness.light);
      expect(settings.terminalThemeFor(Brightness.dark), SolarizedThemes.light);
    });

    test('恢复默认后重新跟随应用主题', () {
      settings.setTerminalBrightness(TerminalBrightness.dark);
      expect(settings.isTerminalBrightnessDefault, isFalse);

      settings.resetTerminalBrightness();
      expect(settings.isTerminalBrightnessDefault, isTrue);
      expect(
        settings.terminalThemeFor(Brightness.light),
        SolarizedThemes.light,
      );
    });
  });
}
