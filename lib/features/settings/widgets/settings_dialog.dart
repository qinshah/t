import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_breakpoints.dart';
import '../../about/widgets/about_dialog.dart';
import '../../terminal/providers/terminal_tabs_provider.dart';
import '../../terminal/services/image_demo.dart';
import '../../update/widgets/update_prompt.dart';
import '../models/setting.dart';
import '../providers/settings_provider.dart';

/// 打开设置对话框。
///
/// 对话框的形态由 [_ResponsiveSettingsDialog] 在每次布局时按当前宽度决定：
/// 宽屏保留内边距并限制最大尺寸；窄屏去掉内边距、铺满窗口。两种形态都
/// 是同一个 [Dialog]，窗口在对话框打开期间跨过断点也会实时调整。
///
/// 这里直接 push [DialogRoute] 而不是 `showDialog`：当前 Flutter SDK 开启
/// windowing 时，`showDialog` 会尝试创建原生对话框窗口并在 macOS 上触发
/// `Multiview can only be enabled before adding any view controllers` 崩溃。
/// [DialogRoute] 仍然是普通路由，渲染在同一个窗口内。
Future<T?> showSettingsDialog<T>(BuildContext context) {
  return showSettingsDialogOn<T>(Navigator.of(context, rootNavigator: true));
}

/// 通过根 [NavigatorState] 打开设置对话框。
///
/// 供没有 [BuildContext] 的入口（如 macOS 应用菜单）使用。
Future<T?> showSettingsDialogOn<T>(NavigatorState navigator) {
  return navigator.push<T>(
    DialogRoute<T>(
      context: navigator.overlay!.context,
      builder: (context) => const _ResponsiveSettingsDialog(),
    ),
  );
}

/// 按当前宽度调整同一个 [Dialog] 的内边距与尺寸约束。
///
/// 两种形态都是普通 [Dialog] 覆盖层，不会触发系统级全屏：
/// - 窄屏：`insetPadding` 为 0，铺满窗口；
/// - 宽屏：保留默认内边距，内容最大 520×560。
///
/// 依赖 `MediaQuery`，窗口尺寸变化时会自动重建。
class _ResponsiveSettingsDialog extends StatelessWidget {
  const _ResponsiveSettingsDialog();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;
    if (!wide) {
      // 铺满窗口时不能有圆角，否则四角会露出底下内容。
      return const Dialog(
        insetPadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: _SettingsBody(),
      );
    }
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: const _SettingsBody(),
      ),
    );
  }
}

/// 设置内容本体；窄屏与宽屏的对话框共用。
class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('设置', style: theme.textTheme.titleLarge),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _PreferenceTile(
                      title: '深色模式',
                      subtitle: '自动跟随系统；暗色 / 亮色固定界面深浅。',
                      modified: !settings.isThemeModeDefault,
                      onReset: settings.resetThemeMode,
                      control: _themeModeControl(
                        settings.themeMode,
                        settings.setThemeMode,
                      ),
                    ),
                    _PreferenceTile(
                      title: '终端深色模式',
                      subtitle: '自动时跟随应用主题深浅；也可单独固定为暗色或亮色。',
                      modified: !settings.isTerminalThemeModeDefault,
                      onReset: settings.resetTerminalThemeMode,
                      control: _themeModeControl(
                        settings.terminalThemeMode,
                        settings.setTerminalThemeMode,
                      ),
                    ),
                    _PreferenceTile(
                      title: '终端字号',
                      subtitle:
                          '范围 $minTerminalFontSize–$maxTerminalFontSize，默认 '
                          '$defaultTerminalFontSize；Ctrl + 0 / - / =、'
                          'Ctrl + 滚轮或双指缩放也可调整。',
                      modified: !settings.isTerminalFontSizeDefault,
                      onReset: settings.resetTerminalFontSize,
                      control: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 140,
                            child: Slider(
                              value: settings.terminalFontSize.toDouble(),
                              min: minTerminalFontSize.toDouble(),
                              max: maxTerminalFontSize.toDouble(),
                              divisions:
                                  maxTerminalFontSize - minTerminalFontSize,
                              label: '${settings.terminalFontSize}',
                              onChanged: (value) =>
                                  settings.setTerminalFontSize(value.round()),
                            ),
                          ),
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${settings.terminalFontSize}',
                              textAlign: TextAlign.end,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PreferenceTile(
                      title: '自动退出',
                      subtitle: '关闭最后一个终端后自动退出应用。',
                      modified: !settings.isQuitWhenLastClosedDefault,
                      onReset: settings.resetQuitWhenLastClosed,
                      control: Switch(
                        value: settings.quitWhenLastClosed,
                        onChanged: settings.setQuitWhenLastClosed,
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          TextButton(
                            onPressed: () => unawaited(
                              checkForUpdates(
                                navigator: Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ),
                                manual: true,
                              ),
                            ),
                            child: const Text('检查更新'),
                          ),
                          TextButton(
                            onPressed: () =>
                                unawaited(_runImageRenderTest(context)),
                            child: const Text('图片渲染测试'),
                          ),
                          TextButton(
                            onPressed: () => unawaited(openAppAbout(context)),
                            child: const Text('关于 t'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 新开一个普通终端标签，并往里面插入 Kitty 图片动画。
Future<void> _runImageRenderTest(BuildContext context) async {
  final tabs = context.read<TerminalTabsProvider>();
  // 先关掉设置，新标签在覆盖层后面才看得见。
  Navigator.of(context, rootNavigator: true).pop();

  await tabs.createTab();
  final session = tabs.activeTab?.session;
  if (tabs.lastError != null || session == null) return;

  try {
    await playImageDemo(session.controller);
  } catch (error, stackTrace) {
    debugPrint('图片渲染测试失败: $error\n$stackTrace');
  }
}

/// 自动 / 暗色 / 亮色三段选择器；两个深浅设置共用。
Widget _themeModeControl(ThemeMode value, ValueChanged<ThemeMode> onChanged) {
  return CupertinoSlidingSegmentedControl<ThemeMode>(
    groupValue: value,
    onValueChanged: (next) {
      if (next != null) onChanged(next);
    },
    children: {
      for (final mode in ThemeMode.values)
        mode: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(mode.label, style: const TextStyle(fontSize: 12)),
        ),
    },
  );
}

/// 单个设置项：标题行右侧是恢复按钮与控件，下一行是简介。
class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.title,
    required this.subtitle,
    required this.modified,
    required this.onReset,
    required this.control,
  });

  /// 设置项名称。
  final String title;

  /// 下一行的简介。
  final String subtitle;

  /// 是否已偏离默认值；只有偏离时才显示恢复按钮。
  final bool modified;

  /// 点击恢复按钮时调用。
  final VoidCallback onReset;

  /// 右侧控件。
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              if (modified)
                IconButton(
                  onPressed: onReset,
                  icon: const Icon(Icons.settings_backup_restore, size: 18),
                  tooltip: '恢复默认',
                  visualDensity: VisualDensity.compact,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              control,
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 8),
            child: Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
