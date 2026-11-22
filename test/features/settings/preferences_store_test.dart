import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:t/features/settings/models/app_preferences.dart';
import 'package:t/features/settings/services/preferences_store.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('t_preferences_test');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  PreferencesStore createStore() {
    return PreferencesStore(directoryProvider: () async => directory);
  }

  group('PreferencesStore', () {
    test('文件不存在时返回默认偏好', () async {
      expect(await createStore().load(), const AppPreferences());
    });

    test('保存后可以读回', () async {
      const preferences = AppPreferences(
        colorMode: AppColorMode.light,
        terminalPalette: TerminalPalette.solarized,
        terminalBrightness: TerminalBrightness.dark,
      );

      await createStore().save(preferences);

      expect(await createStore().load(), preferences);
      expect(
        File(
          '${directory.path}${Platform.pathSeparator}${PreferencesStore.fileName}',
        ).existsSync(),
        isTrue,
      );
    });

    test('损坏的 JSON 回退默认值', () async {
      await File(
        '${directory.path}${Platform.pathSeparator}${PreferencesStore.fileName}',
      ).writeAsString('{not json');

      expect(await createStore().load(), const AppPreferences());
    });

    test('连续保存只保留最后一次内容', () async {
      final store = createStore();

      await store.save(const AppPreferences(colorMode: AppColorMode.dark));
      await store.save(const AppPreferences(colorMode: AppColorMode.light));

      expect((await store.load()).colorMode, AppColorMode.light);
    });
  });
}
