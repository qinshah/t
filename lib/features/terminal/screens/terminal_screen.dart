import 'dart:async';

import 'package:flutter/material.dart';

import '../providers/terminal_tabs_provider.dart';
import '../widgets/terminal_panel.dart';
import '../widgets/terminal_sidebar.dart';

/// 侧边栏与抽屉的切换断点：宽于它用常驻侧边栏，否则收进抽屉。
const double _sidebarBreakpoint = 900;

/// 侧边栏宽度。
const double _sidebarWidth = 264;

/// 多终端工作区。
///
/// 宽屏时标签列表常驻左侧，窄屏时收进 AppBar 的抽屉；两种布局共享同一份
/// 标签状态，切换窗口宽度不会中断任何终端会话。
class TerminalScreen extends StatefulWidget {
  /// 创建终端工作区。
  ///
  /// [createSession] 仅用于测试注入假会话；生产不传，默认创建本地 PTY。
  const TerminalScreen({super.key, this.createSession});

  /// 会话工厂，默认 `LocalPtySession.create`。
  final TerminalSessionFactory? createSession;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final TerminalTabsProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = TerminalTabsProvider(createSession: widget.createSession);
    // 启动即创建首个标签；焦点由 provider 在标签建好后授予。
    unawaited(_provider.createTab());
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final wide =
            MediaQuery.sizeOf(context).width >= _sidebarBreakpoint;
        return wide ? _buildWide(context) : _buildNarrow(context);
      },
    );
  }

  Widget _buildWide(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: _sidebarWidth,
            child: TerminalSidebar(
              provider: _provider,
              onTabSelected: _provider.selectTab,
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          Expanded(child: _Workspace(provider: _provider)),
        ],
      ),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_provider.activeTab?.title ?? '终端'),
        actions: [
          IconButton(
            onPressed: _provider.isCreating
                ? null
                : () => unawaited(_provider.createTab()),
            icon: const Icon(Icons.add),
            tooltip: '新建终端',
          ),
        ],
      ),
      drawer: Drawer(
        width: _sidebarWidth,
        child: TerminalSidebar(
          provider: _provider,
          onTabSelected: (id) {
            _provider.selectTab(id);
            Navigator.of(context).pop();
          },
          onNewTab: () => Navigator.of(context).pop(),
        ),
      ),
      body: _Workspace(provider: _provider),
    );
  }
}

/// 终端内容区：所有会话常驻 widget 树，`IndexedStack` 只显示激活的那个。
///
/// 保活意味着切换标签不会丢滚动缓冲，也不会中断正在运行的程序。
class _Workspace extends StatelessWidget {
  const _Workspace({required this.provider});

  final TerminalTabsProvider provider;

  @override
  Widget build(BuildContext context) {
    final tabs = provider.tabs;
    if (tabs.isEmpty) return _EmptyState(provider: provider);

    final index = provider.activeIndex;
    return IndexedStack(
      index: index < 0 ? 0 : index,
      sizing: StackFit.expand,
      children: [
        for (final tab in tabs)
          TerminalPanel(key: ValueKey(tab.id), session: tab.session),
      ],
    );
  }
}

/// 没有标签时的空状态；创建会话失败时在这里展示原因。
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.provider});

  final TerminalTabsProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final error = provider.lastError;

    return ColoredBox(
      color: const Color(0xFF0E1116),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.terminal,
                  size: 48,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  error == null ? '没有打开的终端' : '终端引擎启动失败',
                  style: theme.textTheme.titleMedium,
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      '$error',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: provider.isCreating
                      ? null
                      : () => unawaited(provider.createTab()),
                  icon: const Icon(Icons.add),
                  label: const Text('新建终端'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
