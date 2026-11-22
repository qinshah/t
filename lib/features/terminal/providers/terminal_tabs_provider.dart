import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:ghostty_dart_flutter/ghostty_dart_flutter.dart'
    show VtTerminalTheme;

import '../models/terminal_tab.dart';
import '../services/local_pty_session.dart';
import '../services/terminal_session.dart';

/// 创建终端会话的工厂。
///
/// 默认实现是本地 PTY；测试通过构造函数注入假会话。
/// 参数是创建时的终端配色。
typedef TerminalSessionFactory = Future<ITerminalSession> Function(
  VtTerminalTheme theme,
);

/// 多终端标签的唯一真相来源。
///
/// 标签顺序、激活项与它们的会话都集中在这里；UI 只读取快照并调用
/// [createTab] / [selectTab] / [closeTab]。
class TerminalTabsProvider extends ChangeNotifier {
  /// 创建 provider。
  ///
  /// [createSession] 仅供测试注入假会话；生产不传即为本地 PTY。
  /// [theme] 是新会话启动时使用的终端配色。
  TerminalTabsProvider({
    TerminalSessionFactory? createSession,
    VtTerminalTheme theme = VtTerminalTheme.defaultTheme,
    this.onLastTabClosed,
  }) : _createSession =
           createSession ??
           ((theme) async => LocalPtySession.create(theme: theme)),
       _terminalTheme = theme;

  final TerminalSessionFactory _createSession;
  final List<TerminalTab> _tabs = <TerminalTab>[];
  VtTerminalTheme _terminalTheme;

  /// 最后一个标签被关闭后的回调；用于按偏好自动退出应用。
  final VoidCallback? onLastTabClosed;

  String? _activeId;
  int _counter = 0;
  bool _creating = false;
  bool _disposed = false;
  Object? _lastError;

  /// 当前打开的标签，按侧边栏展示顺序排列。
  List<TerminalTab> get tabs => List<TerminalTab>.unmodifiable(_tabs);

  /// 当前激活的标签；没有标签时为 `null`。
  TerminalTab? get activeTab {
    final id = _activeId;
    if (id == null) return null;
    for (final tab in _tabs) {
      if (tab.id == id) return tab;
    }
    return null;
  }

  /// 当前激活标签在 [tabs] 中的下标；没有标签时为 -1。
  int get activeIndex {
    final id = _activeId;
    return id == null ? -1 : _tabs.indexWhere((tab) => tab.id == id);
  }

  /// 是否正在创建一个新会话（用于禁用按钮、展示进度）。
  bool get isCreating => _creating;

  /// 最近一次创建会话失败的原因；成功后清空。
  Object? get lastError => _lastError;

  /// 创建一个本地终端标签，并把它切换为激活标签。
  ///
  /// 先建会话再插标签，保证「标签出现时终端已可用」。
  Future<void> createTab() async {
    if (_creating || _disposed) return;
    _creating = true;
    _lastError = null;
    notifyListeners();

    try {
      final session = await _createSession(_terminalTheme);
      if (_disposed) {
        unawaited(session.dispose());
        return;
      }
      _counter++;
      final tab = TerminalTab(
        id: 'terminal-$_counter',
        title: '终端 $_counter',
        session: session,
      );
      _tabs.add(tab);
      _activeId = tab.id;
    } catch (error, stackTrace) {
      debugPrint('TerminalTabsProvider: 创建会话失败: $error\n$stackTrace');
      _lastError = error;
    } finally {
      _creating = false;
      if (!_disposed) notifyListeners();
    }
    _focusActiveAfterFrame();
  }

  /// 切换激活标签。
  void selectTab(String id) {
    if (_disposed || _activeId == id) return;
    if (!_tabs.any((tab) => tab.id == id)) return;
    _activeId = id;
    notifyListeners();
    _focusActiveAfterFrame();
  }

  /// 关闭标签并释放其会话。
  ///
  /// 允许关到 0 个标签：工作区显示空状态，不会自动补建会话。
  void closeTab(String id) {
    if (_disposed) return;
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;

    final removed = _tabs.removeAt(index);
    if (_activeId == id) {
      if (_tabs.isEmpty) {
        _activeId = null;
      } else {
        _activeId = _tabs[index < _tabs.length ? index : _tabs.length - 1].id;
      }
    }
    notifyListeners();
    _disposeSessionAfterFrame(removed.session);
    if (_tabs.isEmpty) {
      onLastTabClosed?.call();
    } else {
      _focusActiveAfterFrame();
    }
  }

  /// 把焦点交给当前激活标签的终端。
  void focusActiveSession() {
    activeTab?.session.focusNode.requestFocus();
  }

  /// 应用新的终端配色。
  ///
  /// 已打开的会话立即换色；之后新建的会话也会使用该配色。
  void updateTerminalTheme(VtTerminalTheme theme) {
    if (_disposed || theme == _terminalTheme) return;
    _terminalTheme = theme;
    for (final tab in _tabs) {
      tab.session.applyTheme(theme);
    }
  }

  /// 等标签内容从 widget 树移除后再释放会话。
  ///
  /// 同步释放会让 `VtTerminalView` 在卸载过程中用到已 dispose 的
  /// `FocusNode` / 控制器。这里不阻塞 UI，PTY 的终止仍在下一帧后完成。
  void _disposeSessionAfterFrame(ITerminalSession session) {
    _afterFrame(() => unawaited(session.dispose()));
  }

  void _focusActiveAfterFrame() {
    _afterFrame(() {
      if (_disposed) return;
      focusActiveSession();
    });
  }

  /// 在下一帧结束后执行 [action]，并显式请求一帧。
  ///
  /// `addPostFrameCallback` 只登记回调、不会自己调度帧；关闭标签时如果恰好
  /// 没有其它失效（例如测试环境），回调永远不会触发，会话就不会被释放。
  void _afterFrame(VoidCallback action) {
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) => action());
    binding.scheduleFrame();
  }

  @override
  void dispose() {
    _disposed = true;
    // 应用退出：立即终止所有 Shell，避免留下孤儿进程。
    for (final tab in _tabs) {
      unawaited(tab.session.dispose());
    }
    _tabs.clear();
    _activeId = null;
    super.dispose();
  }
}
