import 'dart:async';

import 'package:flutter/material.dart';

import '../models/terminal_tab.dart';
import '../providers/terminal_tabs_provider.dart';

/// 多终端标签列表。
///
/// 宽屏时作为常驻侧边栏，窄屏时作为抽屉内容；两处直接复用同一个
/// widget，布局与操作完全一致。处于抽屉中时，操作完成后会自动收起抽屉。
class TerminalSidebar extends StatelessWidget {
  /// 创建标签侧边栏。
  const TerminalSidebar({
    super.key,
    required this.provider,
    required this.onTabSelected,
    required this.onOpenSettings,
  });

  /// 标签与会话的唯一来源。
  final TerminalTabsProvider provider;

  /// 选中标签后的回调。
  final ValueChanged<String> onTabSelected;

  /// 打开设置。
  final VoidCallback onOpenSettings;

  /// 抽屉里的侧边栏在操作后需要收起；常驻侧边栏不受影响。
  void _closeDrawerIfNeeded(BuildContext context) {
    if (context.findAncestorWidgetOfExactType<Drawer>() != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tabs = provider.tabs;

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 8, 12),
              child: Row(
                children: [
                  Icon(Icons.terminal, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    't',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${tabs.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: provider.isCreating
                        ? null
                        : () {
                            unawaited(provider.createTab());
                            _closeDrawerIfNeeded(context);
                          },
                    icon: provider.isCreating
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add, size: 20),
                    tooltip: '新建终端',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () {
                      _closeDrawerIfNeeded(context);
                      onOpenSettings();
                    },
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    tooltip: '设置',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Expanded(
              child: tabs.isEmpty
                  ? Center(
                      child: Text(
                        '没有打开的终端',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: tabs.length,
                      itemBuilder: (context, index) {
                        final tab = tabs[index];
                        return _TabTile(
                          tab: tab,
                          selected: tab.id == provider.activeTab?.id,
                          onTap: () {
                            onTabSelected(tab.id);
                            _closeDrawerIfNeeded(context);
                          },
                          onClose: () => provider.closeTab(tab.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabTile extends StatelessWidget {
  const _TabTile({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final TerminalTab tab;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 4,
              top: 4,
              bottom: 4,
            ),
            child: Row(
              children: [
                Icon(Icons.terminal, size: 16, color: foreground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tab.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: '关闭终端',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  color: foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
