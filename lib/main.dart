import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ghostty_dart/ghostty_dart.dart' show setVtPngDecoder;
import 'package:ghostty_dart_flutter/ghostty_dart_flutter.dart'
    show decodeVtPng;
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/services/preferences_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _enterMacosFrameworkDirectory();
  // Kitty 图形协议的 PNG 解码是进程级钩子，启动时装一次即可。
  setVtPngDecoder(decodeVtPng);

  // 先读完偏好再建界面，避免首帧先闪默认主题再跳变。
  final store = PreferencesStore();
  final settings = SettingsProvider(store: store, initial: await store.load());

  runApp(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: const TerminalApp(),
    ),
  );
}

/// 把工作目录切到 app bundle 的 `Contents/Frameworks`。
///
/// ghostty_dart 的原生资产以相对路径（`ghostty-vt.framework/ghostty-vt`）
/// 交给 `dlopen`，而 `flutter run` 启动的 app 工作目录是工程根目录，直接加载
/// 会找不到库。flutter_pty_new 同样按相对路径打开自己的 framework，切到这里
/// 后两者都能按预期命中。
void _enterMacosFrameworkDirectory() {
  if (!Platform.isMacOS) return;
  final contentsDir = File(Platform.resolvedExecutable).parent.parent;
  final frameworks = Directory('${contentsDir.path}/Frameworks');
  if (frameworks.existsSync()) {
    Directory.current = frameworks;
  }
}
