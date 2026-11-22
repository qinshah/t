import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/update_info.dart';
import '../services/update_service.dart';

/// 是否已有检查在途，避免启动检查与手动检查重复请求。
bool _checking = false;

/// 更新对话框是否已打开，避免叠加多层。
bool _dialogOpen = false;

/// 检查更新入口。
///
/// - [manual] 为 false（启动时）时完全静默，失败不打扰用户；
/// - [manual] 为 true（设置里手动检查）时对“已是最新 / 失败”给出提示。
///
/// [navigator] 用于在当前窗口内打开对话框与提示，不创建新的原生窗口。
Future<void> checkForUpdates({
  required NavigatorState navigator,
  bool manual = false,
}) async {
  if (_checking) return;
  _checking = true;
  try {
    final result = await UpdateService.check();
    if (result == null) {
      if (manual) {
        await _showNotice(navigator, '检查更新失败，仓库还没有可用的 Release');
      }
      return;
    }
    if (!result.hasUpdate) {
      if (manual) {
        await _showNotice(navigator, '已是最新版本 ${result.currentVersion}');
      }
      return;
    }
    // 不等待对话框关闭：_checking 只保护网络请求，不保护用户停留时间。
    unawaited(_showUpdateDialog(navigator, result));
  } catch (error) {
    debugPrint('检查更新失败: $error');
    if (manual) {
      await _showNotice(navigator, '检查更新失败，请检查网络');
    }
  } finally {
    _checking = false;
  }
}

/// 新版本对话框；下载按钮用系统浏览器打开安装包直链。
Future<void> _showUpdateDialog(
  NavigatorState navigator,
  UpdateCheckResult result,
) {
  if (_dialogOpen) return Future<void>.value();
  _dialogOpen = true;
  final url = result.downloadUrl ?? result.releaseUrl;
  return navigator
      .push<void>(
        DialogRoute<void>(
          context: navigator.overlay!.context,
          builder: (context) => _UpdateDialog(
            result: result,
            onDownload: () {
              Navigator.of(context).pop();
              unawaited(_openInBrowser(navigator, url));
            },
          ),
        ),
      )
      .whenComplete(() => _dialogOpen = false);
}

/// 用系统默认浏览器打开链接。
Future<void> _openInBrowser(NavigatorState navigator, String url) async {
  try {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) _showMessage(navigator, '打开下载链接失败');
  } catch (error) {
    debugPrint('打开下载链接失败: $error');
    _showMessage(navigator, '打开下载链接失败');
  }
}

/// 顶部提示；拿不到 ScaffoldMessenger 时静默放弃。
void _showMessage(NavigatorState navigator, String message) {
  ScaffoldMessenger.maybeOf(navigator.context)
      ?.showSnackBar(SnackBar(content: Text(message)));
}

/// 手动检查的结果提示。
///
/// 用 [DialogRoute] 而不是 SnackBar：设置对话框是覆盖层，SnackBar 会被它
/// 挡住（窄屏对话框铺满窗口时完全不可见）。
Future<void> _showNotice(NavigatorState navigator, String message) {
  return navigator.push<void>(
    DialogRoute<void>(
      context: navigator.overlay!.context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    ),
  );
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.result, required this.onDownload});

  final UpdateCheckResult result;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '发现新版本 ${result.latestTag}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                '当前版本 ${result.currentVersion}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (result.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      result.notes,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('稍后'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onDownload,
                    child: Text(result.downloadUrl == null ? '打开发布页' : '下载更新'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
