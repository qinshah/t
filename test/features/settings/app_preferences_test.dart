import 'package:flutter_test/flutter_test.dart';
import 'package:t/features/settings/models/app_preferences.dart';

void main() {
  group('AppPreferences', () {
    test('默认值集中在 AppDefaults', () {
      const defaults = AppPreferences();

      expect(defaults.colorMode, AppDefaults.colorMode);
      expect(defaults.terminalPalette, AppDefaults.terminalPalette);
      expect(defaults.terminalBrightness, AppDefaults.terminalBrightness);
      expect(AppDefaults.colorMode, AppColorMode.auto);
      expect(AppDefaults.terminalPalette, TerminalPalette.solarized);
      expect(
        AppDefaults.terminalBrightness,
        TerminalBrightness.followColorMode,
      );
    });

    test('toJson / fromJson 往返', () {
      const preferences = AppPreferences(
        colorMode: AppColorMode.dark,
        terminalPalette: TerminalPalette.solarized,
        terminalBrightness: TerminalBrightness.dark,
      );

      final restored = AppPreferences.fromJson(preferences.toJson());

      expect(restored, preferences);
      expect(preferences.toJson()['version'], 2);
      expect(preferences.toJson()['colorMode'], 'dark');
      expect(preferences.toJson()['terminalPalette'], 'solarized');
      expect(preferences.toJson()['terminalBrightness'], 'dark');
    });

    test('旧版本的深浅配色名折叠为 solarized', () {
      final light = AppPreferences.fromJson(const {
        'terminalPalette': 'solarizedLight',
      });
      final dark = AppPreferences.fromJson(const {
        'terminalPalette': 'solarizedDark',
      });

      expect(light.terminalPalette, TerminalPalette.solarized);
      expect(dark.terminalPalette, TerminalPalette.solarized);
      // 旧配置没有独立深浅项，回退默认的「随颜色」。
      expect(light.terminalBrightness, TerminalBrightness.followColorMode);
      expect(dark.terminalBrightness, TerminalBrightness.followColorMode);
    });

    test('未知枚举值与错误类型回退默认', () {
      final restored = AppPreferences.fromJson(const {
        'colorMode': 'unknown',
        'terminalPalette': 42,
        'terminalBrightness': false,
      });

      expect(restored, const AppPreferences());
    });

    test('缺失字段回退默认', () {
      final restored = AppPreferences.fromJson(const {});

      expect(restored, const AppPreferences());
    });
  });
}
