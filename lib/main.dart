import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ghostty_dart/ghostty_dart.dart' show setVtPngDecoder;
import 'package:ghostty_dart_flutter/ghostty_dart_flutter.dart'
    show decodeVtPng;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'app_menu.dart';
import 'features/settings/models/setting.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _enterMacosFrameworkDirectory();
  // Kitty 图形协议的 PNG 解码是进程级钩子，启动时装一次即可。
  setVtPngDecoder(decodeVtPng);

  // 先把偏好读进内存，再建界面；Setting.get 是同步读取，不会闪默认主题。
  final store = SettingsStore();
  await store.load();
  Setting.store = store;

  // macOS 菜单（About / Settings…）走同一个 channel，窗口建好后即可响应。
  bindAppMenuChannel();

  runApp(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: SettingsProvider(),
      child: const TerminalApp(),
    ),
  );

  // 界面起来后再申请，权限弹窗/系统设置页不会挡住启动。
  unawaited(_requestAllFilesAccessOnce());
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

/// 检查并申请一次「所有文件访问」权限，仅 Android。
///
/// 终端要读写设备上的任意目录，需要 `MANAGE_EXTERNAL_STORAGE`（Android 11+）。
/// 已授权时直接返回；未授权时交给 permission_handler 拉起系统授权页面，
/// 只申请一次，不反复打扰。权限失败不影响应用启动。
Future<void> _requestAllFilesAccessOnce() async {
  if (!Platform.isAndroid) return;
  try {
    if (await Permission.manageExternalStorage.isGranted) return;
    await Permission.manageExternalStorage.request();
  } catch (error) {
    debugPrint('权限申请失败：$error');
  }
}
