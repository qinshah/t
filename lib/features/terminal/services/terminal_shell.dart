import 'dart:io';

/// 安卓上 Shell 可访问的外部存储根目录，用来替代缺失的 `HOME`。
const String androidExternalStorage = '/storage/emulated/0';

/// 启动一个本地 Shell 所需的全部参数。
class ShellSpec {
  const ShellSpec({
    required this.program,
    this.arguments = const [],
    this.workingDirectory,
    this.environment,
  });

  /// Shell 可执行文件。
  final String program;

  /// 传给 Shell 的参数（macOS 的登录 Shell 需要 `-l`）。
  final List<String> arguments;

  /// 起始目录；`null` 表示继承进程当前目录。
  final String? workingDirectory;

  /// 追加给子进程的环境变量，覆盖继承值。
  final Map<String, String>? environment;

  /// 复制一份并替换起始目录。
  ShellSpec copyWith({String? workingDirectory}) {
    return ShellSpec(
      program: program,
      arguments: arguments,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      environment: environment,
    );
  }
}

/// 推导本地 Shell 的启动参数，使默认行为与系统终端一致。
///
/// 显式决定可执行文件、起始目录与 `HOME`，不依赖 flutter_pty_new 的缺省值
/// （它在 Windows 上无条件用 `cmd.exe`，起始目录也只在安卓兜底）。
///
/// [fileExists] / [directoryExists] 供测试注入文件系统探测。
ShellSpec resolveShellSpec({
  required String operatingSystem,
  required Map<String, String> environment,
  bool Function(String path)? fileExists,
  bool Function(String path)? directoryExists,
}) {
  final fs = _FsProbe(fileExists: fileExists, directoryExists: directoryExists);
  return switch (operatingSystem) {
    'windows' => _windowsShell(environment, fs),
    'android' => _androidShell(environment, fs),
    // macOS 的 GUI app 继承 launchd 的精简 PATH，只有登录 Shell 会执行
    // `/etc/zprofile` 的 path_helper 补齐 Homebrew 等路径，与 Terminal.app 一致。
    'macos' => _posixShell(environment, fs, login: true),
    _ => _posixShell(environment, fs),
  };
}

ShellSpec _windowsShell(Map<String, String> env, _FsProbe fs) {
  return ShellSpec(
    program: _windowsExecutable(env, fs) ?? 'cmd.exe',
    workingDirectory: fs.firstDirectory(
      _windowsHomeCandidates(env),
      requireAscii: true,
    ),
    // flutter_pty_new 会用显式的 environment 调 CreateProcessW，自身只放
    // TERM/LANG/PATH/HOME 等少量变量；Windows 子进程拿不到 SystemRoot、
    // USERPROFILE、APPDATA 时，PowerShell 5.1 无法加载托管运行时
    // （0x8009001d）。把父进程环境原样带上，等价于系统终端启动 shell。
    environment: Map<String, String>.from(env),
  );
}

/// 按 PowerShell 7 → Windows 内置 PowerShell → cmd 的优先级挑选 Shell。
String? _windowsExecutable(Map<String, String> env, _FsProbe fs) {
  final pathDirs = _pathEntries(env['PATH']);
  return fs.firstFile([
    for (final dir in pathDirs) _join(dir, r'pwsh.exe'),
    _join(env['ProgramFiles'], r'PowerShell\7\pwsh.exe'),
    for (final dir in pathDirs) _join(dir, r'powershell.exe'),
    _join(env['SystemRoot'], r'System32\WindowsPowerShell\v1.0\powershell.exe'),
    env['COMSPEC'],
  ], requireAscii: true);
}

Iterable<String?> _windowsHomeCandidates(Map<String, String> env) sync* {
  yield env['USERPROFILE'];
  final drive = env['HOMEDRIVE'];
  final path = env['HOMEPATH'];
  if (drive != null && drive.isNotEmpty && path != null && path.isNotEmpty) {
    yield '$drive$path';
  }
}

ShellSpec _androidShell(Map<String, String> env, _FsProbe fs) {
  // 安卓 app 进程一般没有可用的 `HOME`，`cd` 不带参数会直接报
  // "no home directory"，因此把外部存储根目录同时作为起始目录和 `HOME`。
  final home = fs.firstDirectory([androidExternalStorage, env['HOME']]);
  return ShellSpec(
    program:
        fs.firstFile([
          env['SHELL'],
          '/system/bin/sh',
          '/bin/sh',
          '/system/xbin/sh',
        ]) ??
        '/system/bin/sh',
    workingDirectory: home,
    environment: {..._termEnvironment(env), 'HOME': ?home},
  );
}

ShellSpec _posixShell(
  Map<String, String> env,
  _FsProbe fs, {
  bool login = false,
}) {
  return ShellSpec(
    program:
        fs.firstFile([env['SHELL'], '/bin/bash', '/bin/zsh', '/bin/sh']) ??
        '/bin/sh',
    arguments: login ? const ['-l'] : const [],
    workingDirectory: fs.firstDirectory([env['HOME']]),
    environment: _termEnvironment(env),
  );
}

/// 父进程环境缺少 `TERM` 时补一个 `xterm-256color`。
///
/// `flutter_pty_new` 内部也会兜底设置 `TERM`，但那是插件的隐式行为；
/// 在 `ShellSpec` 里显式给出后，颜色相关行为可以单测，也方便未来替换
/// PTY 后端时保持一致。已有非空 `TERM` 时不覆盖。
Map<String, String> _termEnvironment(Map<String, String> env) {
  final term = env['TERM'];
  if (term != null && term.isNotEmpty) return const {};
  return const {'TERM': 'xterm-256color'};
}

/// 存在性探测，缺省走真实文件系统，测试可注入。
class _FsProbe {
  _FsProbe({
    bool Function(String path)? fileExists,
    bool Function(String path)? directoryExists,
  }) : fileExists = fileExists ?? _fileExists,
       directoryExists = directoryExists ?? _directoryExists;

  final bool Function(String path) fileExists;
  final bool Function(String path) directoryExists;

  String? firstFile(
    Iterable<String?> candidates, {
    bool requireAscii = false,
  }) => _first(candidates, fileExists, requireAscii: requireAscii);

  String? firstDirectory(
    Iterable<String?> candidates, {
    bool requireAscii = false,
  }) => _first(candidates, directoryExists, requireAscii: requireAscii);

  String? _first(
    Iterable<String?> candidates,
    bool Function(String path) exists, {
    required bool requireAscii,
  }) {
    for (final candidate in candidates) {
      if (candidate == null || candidate.isEmpty) continue;
      // flutter_pty_new 的 Windows 原生层把 UTF-8 字符串按字节扩展成 UTF-16，
      // 含非 ASCII 的路径会被破坏、`CreateProcessW` 直接失败，整个终端起不来。
      // 这类候选宁可跳过，也不能传给 PTY。
      if (requireAscii && !_isAscii(candidate)) continue;
      if (exists(candidate)) return candidate;
    }
    return null;
  }
}

/// 探测路径是否存在。
///
/// 沙箱读不到的路径（EACCES）按不可用处理，避免整个会话起不来。
bool _fileExists(String path) => _exists(() => File(path).existsSync());

bool _directoryExists(String path) =>
    _exists(() => Directory(path).existsSync());

bool _exists(bool Function() probe) {
  try {
    return probe();
  } on FileSystemException {
    return false;
  }
}

bool _isAscii(String value) => value.codeUnits.every((unit) => unit < 0x80);

/// 拆分 Windows `PATH`，去掉空项与包裹的引号。
List<String> _pathEntries(String? path) {
  if (path == null || path.isEmpty) return const [];
  return [
    for (final entry in path.split(';'))
      if (entry.trim().isNotEmpty) _unquote(entry.trim()),
  ];
}

String _unquote(String value) {
  if (value.length > 1 && value.startsWith('"') && value.endsWith('"')) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

/// 拼接目录与文件名，容忍目录端已有的分隔符。
String? _join(String? directory, String fileName) {
  if (directory == null || directory.isEmpty) return null;
  if (directory.endsWith(r'\') || directory.endsWith('/')) {
    return '$directory$fileName';
  }
  return '$directory\\$fileName';
}
