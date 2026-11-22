import 'package:flutter/widgets.dart';
import 'package:ghostty_dart_flutter/ghostty_dart_flutter.dart';

import '../services/terminal_session.dart';

/// 终端面板：`VtTerminalView` 的薄封装。
///
/// 只按会话绑定控制器与焦点节点，不感知会话背后是本地 PTY 还是远程连接。
class TerminalPanel extends StatelessWidget {
  /// 创建一个绑定到 [session] 的终端面板。
  const TerminalPanel({super.key, required this.session});

  /// 面板要渲染的终端会话。
  final ITerminalSession session;

  @override
  Widget build(BuildContext context) {
    final controller = session.controller;
    return ColoredBox(
      // 与终端自身的背景一致，避免首帧前闪一下 Scaffold 的底色。
      color: controller.theme.background,
      child: VtTerminalView(
        controller: controller,
        focusNode: session.focusNode,
        // 所有标签常驻 widget 树（IndexedStack 保活），焦点只能由 provider
        // 在切换标签时显式授予，否则多个终端会争夺初始焦点。
        autofocus: false,
        textStyle: const TextStyle(fontSize: 13),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      ),
    );
  }
}
