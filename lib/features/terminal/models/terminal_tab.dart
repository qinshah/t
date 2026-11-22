import '../services/terminal_session.dart';

/// 一个终端标签：会话本身加上用于展示的名字。
class TerminalTab {
  const TerminalTab({
    required this.id,
    required this.title,
    required this.session,
  });

  /// 稳定标识，用于关闭、选中与 widget key；不随标签顺序变化。
  final String id;

  /// 标签展示名，默认是「终端 N」。
  final String title;

  /// 该标签独占的终端会话。
  final ITerminalSession session;
}
