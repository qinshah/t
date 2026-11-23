import 'package:flutter_test/flutter_test.dart';
import 'package:t/features/terminal/services/terminal_shell.dart';

void main() {
  group('resolveShellSpec 的 TERM 兜底', () {
    test('macOS 缺少 TERM 时注入 xterm-256color', () {
      final spec = resolveShellSpec(
        operatingSystem: 'macos',
        environment: const {'SHELL': '/bin/zsh', 'HOME': '/Users/me'},
        fileExists: (_) => true,
        directoryExists: (_) => true,
      );

      expect(spec.environment?['TERM'], 'xterm-256color');
      expect(spec.arguments, const ['-l']);
    });

    test('已有 TERM 时不覆盖', () {
      final spec = resolveShellSpec(
        operatingSystem: 'linux',
        environment: const {'TERM': 'screen-256color', 'HOME': '/home/me'},
        fileExists: (_) => true,
        directoryExists: (_) => true,
      );

      expect(spec.environment, isNot(contains('TERM')));
    });

    test('TERM 为空字符串时按缺失处理', () {
      final spec = resolveShellSpec(
        operatingSystem: 'linux',
        environment: const {'TERM': '', 'HOME': '/home/me'},
        fileExists: (_) => true,
        directoryExists: (_) => true,
      );

      expect(spec.environment?['TERM'], 'xterm-256color');
    });

    test('Android 注入 TERM 并保留 HOME', () {
      final spec = resolveShellSpec(
        operatingSystem: 'android',
        environment: const {},
        fileExists: (_) => true,
        directoryExists: (path) => path == androidExternalStorage,
      );

      expect(spec.environment?['HOME'], androidExternalStorage);
      expect(spec.environment?['TERM'], 'xterm-256color');
    });

    test('Windows 继承父进程环境供 PowerShell 初始化', () {
      final spec = resolveShellSpec(
        operatingSystem: 'windows',
        environment: const {
          'COMSPEC': r'C:\Windows\System32\cmd.exe',
          'USERPROFILE': r'C:\Users\me',
          'SystemRoot': r'C:\Windows',
          'APPDATA': r'C:\Users\me\AppData\Roaming',
        },
        fileExists: (_) => true,
        directoryExists: (_) => true,
      );

      expect(spec.environment, containsPair('SystemRoot', r'C:\Windows'));
      expect(spec.environment, containsPair('APPDATA', r'C:\Users\me\AppData\Roaming'));
      expect(spec.environment?['TERM'], isNull);
    });
  });
}
