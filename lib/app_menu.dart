import 'package:flutter/services.dart';

import 'app.dart';
import 'features/about/widgets/about_dialog.dart';
import 'features/settings/widgets/settings_dialog.dart';

/// macOS 应用菜单事件通道。
///
/// 原生侧在 `macos/Runner/AppDelegate.swift` 里把菜单项（About / Settings…）
/// 转发过来，这里再分发到对应模块的对话框。两者都用 `DialogRoute` 覆盖在
/// 当前窗口内，不创建原生窗口，避免触发 Flutter 引擎的 Multiview 断言。
const MethodChannel _channel = MethodChannel('com.ivi.t/app_menu');

/// 对话框是否已打开；菜单可重复触发，避免叠加多层。
bool _settingsOpen = false;
bool _aboutOpen = false;

/// 绑定 macOS 应用菜单事件；应用启动时调用一次。
void bindAppMenuChannel() {
  _channel.setMethodCallHandler(_handleCall);
}

Future<void> _handleCall(MethodCall call) async {
  if (call.method == 'openSettings') {
    await _openSettings();
  } else if (call.method == 'openAbout') {
    await _openAbout((call.arguments as Map?) ?? const {});
  }
}

Future<void> _openSettings() async {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null || _settingsOpen) return;
  _settingsOpen = true;
  await showSettingsDialogOn<void>(navigator);
  _settingsOpen = false;
}

Future<void> _openAbout(Map<Object?, Object?> info) async {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null || _aboutOpen) return;
  _aboutOpen = true;
  await showAppAboutDialogOn(
    navigator,
    name: info['name'] as String? ?? 't',
    version: info['version'] as String? ?? '',
    copyright: info['copyright'] as String?,
  );
  _aboutOpen = false;
}
