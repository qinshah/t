import 'package:flutter/widgets.dart';
import 'package:ghostty_dart_flutter/ghostty_dart_flutter.dart';

/// 一个终端会话对 UI 暴露的最小契约。
///
/// 会话负责字节从哪来、往哪去；UI 只消费 [controller] 与 [focusNode]。
/// 本地 PTY 与未来的 SSH 会话都实现该接口，因此终端面板不感知传输层。
abstract interface class ITerminalSession {
  /// libghostty-vt 终端控制器：屏幕缓冲、输入编码与重绘通知都在这里。
  VtTerminalController get controller;

  /// 该会话专用的焦点节点，由会话自己创建并释放。
  FocusNode get focusNode;

  /// 应用新的终端配色；已存在的屏幕颜色立即更新，不重建会话。
  void applyTheme(VtTerminalTheme theme);

  /// 停止订阅、终止进程并释放全部资源；重复调用必须安全。
  Future<void> dispose();
}
