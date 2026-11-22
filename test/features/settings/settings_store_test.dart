import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:t/features/settings/services/settings_store.dart';

void main() {
  late Directory directory;
  late SettingsStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('t_settings_store');
    store = SettingsStore(directoryProvider: () async => directory);
    await store.load();
  });

  tearDown(() async {
    await store.flush();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  File file() => File(
    '${directory.path}${Platform.pathSeparator}${SettingsStore.fileName}',
  );

  test('文件不存在时为空', () {
    expect(store.get<String>('themeMode'), isNull);
  });

  test('写入后可以重新读取，且只存基本类型', () async {
    await store.put('themeMode', 'dark');
    await store.put('quitWhenLastClosed', true);
    await store.flush();

    expect(file().existsSync(), isTrue);
    expect(file().readAsStringSync(), contains('"themeMode": "dark"'));
    expect(file().readAsStringSync(), contains('"quitWhenLastClosed": true'));

    final reopened = SettingsStore(directoryProvider: () async => directory);
    await reopened.load();

    expect(reopened.get<String>('themeMode'), 'dark');
    expect(reopened.get<bool>('quitWhenLastClosed'), isTrue);
  });

  test('删除项后重新读取为空', () async {
    await store.put('themeMode', 'dark');
    await store.remove('themeMode');
    await store.flush();

    final reopened = SettingsStore(directoryProvider: () async => directory);
    await reopened.load();

    expect(reopened.get<String>('themeMode'), isNull);
  });

  test('损坏的 JSON 回退为空表', () async {
    await file().writeAsString('{not json');

    final reopened = SettingsStore(directoryProvider: () async => directory);
    await reopened.load();

    expect(reopened.get<String>('themeMode'), isNull);
  });

  test('内存实现不写文件', () async {
    final memory = SettingsStore.memory();
    await memory.put('themeMode', 'light');

    expect(memory.get<String>('themeMode'), 'light');
  });
}
