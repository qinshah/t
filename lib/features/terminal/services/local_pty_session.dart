import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_pty_new/flutter_pty_new.dart';
import 'package:ghostty_dart_flutter/ghostty_dart_flutter.dart';

import 'terminal_session.dart';
import 'terminal_shell.dart';

/// 由本地伪终端（PTY）支撑的终端会话。
///
/// libghostty-vt 负责 VT 解析、屏幕缓冲与重绘；flutter_pty_new 负责真正
/// 跑 Shell。两者之间只连三根线：
///   * PTY 输出 → `controller.writeBytes`
///   * `controller.onOutput` → PTY 写入
///   * `controller.onResize` → PTY 尺寸
///
/// PTY 延迟到首次拿到真实行列数（首帧布局完成）时才启动，避免用 80×24
/// 的假尺寸起进程，让全屏程序一上来就按错误宽度排版。
class LocalPtySession implements ITerminalSession {
  LocalPtySession._({required this.shell});

  /// 创建一个本地 PTY 会话。
  ///
  /// [shell] 仅用于测试注入；生产按平台自动推导。
  /// [theme] 是启动时的终端配色，之后可通过 [applyTheme] 覆盖。
  factory LocalPtySession.create({
    ShellSpec? shell,
    VtTerminalTheme theme = VtTerminalTheme.defaultTheme,
  }) {
    final spec =
        shell ??
        resolveShellSpec(
          operatingSystem: Platform.operatingSystem,
          environment: Platform.environment,
        );
    final session = LocalPtySession._(shell: spec);
    // 回调在视图开始写数据之后才会触发，此时控制器已经就绪。
    session._controller = VtTerminalController(
      theme: theme,
      onOutput: session._writeToPty,
      onResize: (cols, rows, pixelWidth, pixelHeight) =>
          session._resize(cols, rows),
    );
    return session;
  }

  late final VtTerminalController _controller;

  @override
  VtTerminalController get controller => _controller;

  @override
  final FocusNode focusNode = FocusNode(debugLabel: 'terminal-pty');

  @override
  void applyTheme(VtTerminalTheme theme) {
    if (_disposed) return;
    _controller.theme = theme;
  }

  /// 本次会话用于启动 Shell 的参数。
  final ShellSpec shell;

  Pty? _pty;
  StreamSubscription<Uint8List>? _output;
  bool _exited = false;
  bool _disposed = false;

  /// 终端尺寸的唯一入口，由 `VtTerminalView` 的 `onResize` 驱动。
  ///
  /// 首次调用启动 PTY；此后只转发尺寸变化。flutter_pty_new 的
  /// `Pty.resize(rows, cols)` 与 `onResize(cols, rows)` 参数顺序相反，
  /// 这里显式按 `(rows, cols)` 传参，避免全屏程序布局错乱。
  void _resize(int cols, int rows) {
    if (_disposed || _exited) return;
    if (cols <= 0 || rows <= 0) return;

    final pty = _pty;
    if (pty == null) {
      _startPty(cols, rows);
      return;
    }
    pty.resize(rows, cols);
  }

  /// 启动 PTY 并接好双向管线。
  ///
  /// 构造 `Pty` 即 spawn 进程；失败时不向上抛异常，而是把错误写进终端，
  /// 让界面仍有一个可解释的状态。
  void _startPty(int cols, int rows) {
    try {
      final pty = _createPty(cols, rows);
      _pty = pty;
      _output = pty.output.listen(controller.writeBytes);
      unawaited(pty.exitCode.then((_) => _markExited()));
    } catch (error, stackTrace) {
      debugPrint('LocalPtySession: 启动 PTY 失败: $error\n$stackTrace');
      _markExited();
      controller.write('\r\n无法启动本地终端：$error\r\n');
    }
  }

  void _writeToPty(Uint8List data) {
    if (_disposed || _exited || data.isEmpty) return;
    try {
      _pty?.write(data);
    } catch (error) {
      // PTY 已关闭时写入失败；进程退出会通过 exitCode 反映出来。
      debugPrint('LocalPtySession: 写入 PTY 失败: $error');
    }
  }

  /// 创建 PTY 后端。
  ///
  /// flutter_pty_new 在 macOS 上固定以相对工作目录的路径
  /// `flutter_pty_new.framework/flutter_pty_new` 打开动态库，而 app 从
  /// `flutter run` 启动时工作目录是工程根目录，直接加载会失败。
  /// 这里在构造期间临时把工作目录切到 app bundle 的 `Contents/Frameworks`，
  /// 让库自身的相对路径命中；Shell 的起始目录因此必须显式指定。
  Pty _createPty(int cols, int rows) {
    final workingDirectory = shell.workingDirectory;
    if (!Platform.isMacOS) {
      return _spawn(cols, rows, workingDirectory);
    }
    final frameworks = _macosFrameworksDirectory();
    if (frameworks == null) {
      return _spawn(cols, rows, workingDirectory);
    }
    final original = Directory.current;
    Directory.current = frameworks;
    try {
      return _spawn(cols, rows, workingDirectory ?? original.path);
    } finally {
      Directory.current = original;
    }
  }

  Pty _spawn(int cols, int rows, String? workingDirectory) {
    return Pty.start(
      shell.program,
      arguments: shell.arguments,
      workingDirectory: workingDirectory,
      environment: shell.environment,
      rows: rows,
      columns: cols,
    );
  }

  Directory? _macosFrameworksDirectory() {
    final contentsDir = File(Platform.resolvedExecutable).parent.parent;
    final frameworks = Directory('${contentsDir.path}/Frameworks');
    return frameworks.existsSync() ? frameworks : null;
  }

  void _markExited() {
    if (_disposed) return;
    _exited = true;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final output = _output;
    _output = null;
    await output?.cancel();

    final pty = _pty;
    _pty = null;
    if (pty != null) {
      try {
        // Unix 上交互式 bash/zsh 会忽略 SIGTERM，用 SIGHUP 才能像关窗口一样
        // 结束 Shell；Windows 没有信号，按默认终止。
        pty.kill(
          Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sighup,
        );
      } catch (_) {
        // 进程可能已经自然退出，kill 失败不应阻塞资源释放。
      }
    }

    controller.dispose();
    focusNode.dispose();
  }
}
