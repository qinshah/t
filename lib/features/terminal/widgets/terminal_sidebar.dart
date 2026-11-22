import 'dart:async';

import 'package:flutter/material.dart';

import '../models/terminal_tab.dart';
import '../providers/terminal_tabs_provider.dart';

/// 多终端标签列表。
///
/// 宽屏时作为常驻侧边栏，窄屏时作为抽屉内容；两者只是容器不同，
/// 列表与操作完全一致。
class TerminalSidebar extends StatelessWidget {
  /// 创建标签侧边栏。
  const TerminalSidebar({
    super.key,
    required this.provider,
    this.onTabSelected,
    this.onNewTab,
  });

  /// 标签与会话的唯一来源。
  final TerminalTabsProvider provider;

  /// 选中标签后的回调；窄屏用它关闭抽屉。
  final ValueChanged<String>? onTabSelected;

  /// 新建标签之后的回调；窄屏用它关闭抽屉。
  final VoidCallback? onNewTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tabs = provider.tabs;

    return Material(
      color: const Color(0xFF12151B),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
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
                          onTap: () => onTabSelected?.call(tab.id),
                          onClose: () => provider.closeTab(tab.id),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.tonalIcon(
                onPressed: provider.isCreating
                    ? null
                    : () {
                        unawaited(provider.createTab());
                        onNewTab?.call();
                      },
                icon: provider.isCreating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add, size: 18),
                label: const Text('新建终端'),
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
            padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
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
