import 'package:flutter/material.dart';

/// 打开“关于”对话框。
///
/// macOS 系统自带的 About 面板会新建原生窗口，触发 Flutter 引擎
/// `enableMultiView` 的断言崩溃（与 `showDialog` 同源）。这里和设置对话框
/// 一样用 [DialogRoute] 覆盖在当前窗口内，不创建新的原生窗口。
Future<void> showAppAboutDialog(
  BuildContext context, {
  required String name,
  required String version,
  String? copyright,
}) {
  return showAppAboutDialogOn(
    Navigator.of(context, rootNavigator: true),
    name: name,
    version: version,
    copyright: copyright,
  );
}

/// 通过根 [NavigatorState] 打开“关于”对话框。
///
/// 供没有 [BuildContext] 的入口（如 macOS 应用菜单）使用。
Future<void> showAppAboutDialogOn(
  NavigatorState navigator, {
  required String name,
  required String version,
  String? copyright,
}) {
  return navigator.push<void>(
    DialogRoute<void>(
      context: navigator.overlay!.context,
      builder: (context) =>
          _AboutDialog(name: name, version: version, copyright: copyright),
    ),
  );
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog({
    required this.name,
    required this.version,
    required this.copyright,
  });

  /// 应用名，来自 `CFBundleName`。
  final String name;

  /// 版本号，来自 `CFBundleShortVersionString`。
  final String version;

  /// 版权信息，来自 `NSHumanReadableCopyright`。
  final String? copyright;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final infoStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.terminal_rounded,
                    size: 40,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (version.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '版本 $version',
                  textAlign: TextAlign.center,
                  style: infoStyle,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '基于 ghostty 的多标签终端',
                textAlign: TextAlign.center,
                style: infoStyle,
              ),
              if (copyright != null && copyright!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  copyright!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
