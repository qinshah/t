import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:t/features/settings/models/setting.dart';
import 'package:t/features/settings/services/settings_store.dart';

void main() {
  setUp(() {
    Setting.store = SettingsStore.memory();
  });

  tearDown(() {
    Setting.store = SettingsStore.memory();
  });

  test('默认值', () {
    expect(Setting.themeMode.get(), ThemeMode.system);
    expect(Setting.terminalThemeMode.get(), ThemeMode.system);
    expect(Setting.quitWhenLastClosed.get(), isTrue);
    expect(Setting.themeMode.isDefault, isTrue);
    expect(Setting.terminalThemeMode.isDefault, isTrue);
    expect(Setting.quitWhenLastClosed.isDefault, isTrue);
  });

  test('set 只存基本类型，get 时再解码', () async {
    await Setting.themeMode.set(ThemeMode.dark);

    expect(Setting.store.get<String>('themeMode'), 'dark');
    expect(Setting.themeMode.get(), ThemeMode.dark);
    expect(Setting.themeMode.isDefault, isFalse);
  });

  test('恢复默认会删除存储项', () async {
    await Setting.terminalThemeMode.set(ThemeMode.light);
    expect(Setting.store.get<String>('terminalThemeMode'), 'light');

    await Setting.terminalThemeMode.reset();

    expect(Setting.store.get<String>('terminalThemeMode'), isNull);
    expect(Setting.terminalThemeMode.get(), ThemeMode.system);
    expect(Setting.terminalThemeMode.isDefault, isTrue);
  });

  test('设置回默认值等同于删除', () async {
    await Setting.quitWhenLastClosed.set(false);
    expect(Setting.store.get<bool>('quitWhenLastClosed'), isFalse);

    await Setting.quitWhenLastClosed.set(true);

    expect(Setting.store.get<bool>('quitWhenLastClosed'), isNull);
    expect(Setting.quitWhenLastClosed.get(), isTrue);
  });

  test('未知的模式名回退自动', () async {
    await Setting.store.put('themeMode', 'unknown');

    expect(Setting.themeMode.get(), ThemeMode.system);
  });

  test('标签翻译复用 ThemeMode', () {
    expect(ThemeMode.system.label, '自动');
    expect(ThemeMode.dark.label, '暗色');
    expect(ThemeMode.light.label, '亮色');
  });
}
