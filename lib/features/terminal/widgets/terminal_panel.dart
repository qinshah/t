import 'package:flutter/widgets.dart';
import 'package:ghostty_dart/ghostty_dart.dart' show VtCursorStyle;
import 'package:ghostty_dart_flutter/ghostty_dart_flutter.dart';

import '../services/terminal_session.dart';

/// 终端面板：`VtTerminalView` 的薄封装。
///
/// 只按会话绑定控制器与焦点节点，不感知会话背后是本地 PTY 还是远程连接。
class TerminalPanel extends StatelessWidget {
  /// 创建一个绑定到 [session] 的终端面板。
  ///
  /// 光标默认使用竖向条并带 160ms 缓动；调用方可以按标签覆盖样式与时长。
  const TerminalPanel({
    super.key,
    required this.session,
    this.cursorStyle = VtCursorStyle.bar,
    this.cursorGlide = true,
    this.cursorGlideDuration = const Duration(milliseconds: 160),
    this.barCursorThicknessFraction = 1 / 5,
  });

  /// 面板要渲染的终端会话。
  final ITerminalSession session;

  /// 覆盖程序通过 DECSCUSR 请求的光标形状。
  final VtCursorStyle? cursorStyle;

  /// 光标跨单元格移动时是否缓动。
  final bool cursorGlide;

  /// 光标缓动时长；`Duration.zero` 表示直接跳转。
  final Duration cursorGlideDuration;

  /// 条状光标的宽度占单元格宽度的比例；上游默认 1/8，这里默认更粗的 1/5。
  final double barCursorThicknessFraction;

  @override
  Widget build(BuildContext context) {
    final controller = session.controller;
    // 配色可以在运行中切换，底色也要跟着控制器一起重建。
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
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
            cursorStyle: cursorStyle,
            cursorGlide: cursorGlide,
            cursorGlideDuration: cursorGlideDuration,
            barCursorThicknessFraction: barCursorThicknessFraction,
          ),
        );
      },
    );
  }
}
