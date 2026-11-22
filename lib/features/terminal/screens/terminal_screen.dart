import 'dart:async';

import 'package:flutter/material.dart';
import 'package:panes/panes.dart';
import 'package:provider/provider.dart';

import '../../../app_breakpoints.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/widgets/settings_dialog.dart';
import '../providers/terminal_tabs_provider.dart';
import '../widgets/terminal_panel.dart';
import '../widgets/terminal_sidebar.dart';

/// 侧边栏初始宽度，也是窄屏抽屉宽度。
const double _sidebarInitialWidth = 264;

/// 侧边栏可拖动的最小宽度。
const double _sidebarMinWidth = 200;

/// 侧边栏可拖动的最大宽度。
const double _sidebarMaxWidth = 420;

/// 多终端工作区。
///
/// 宽屏时标签列表常驻左侧，且可以通过分隔条拖动调宽；窄屏时收进 AppBar
/// 的抽屉。两种布局共享同一份标签状态，切换窗口宽度不会中断任何终端会话。
class TerminalScreen extends StatefulWidget {
  /// 创建终端工作区。
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final SettingsProvider _settings;
  late final TerminalTabsProvider _provider;

  /// 宽屏侧边栏与内容区的分栏控制器；窄屏时不渲染但保留宽度状态。
  late final PaneController _panes;

  /// 当前应用主题的实际亮度；`随颜色` 时终端据此选深浅。
  Brightness _appBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>();
    // 标签状态由应用层持有，设置等覆盖层也能访问。
    _provider = context.read<TerminalTabsProvider>();
    _panes = PaneController(
      entries: [
        PaneEntry(
          id: 'sidebar',
          initialSize: PaneSize.pixel(_sidebarInitialWidth),
          minSize: PaneSize.pixel(_sidebarMinWidth),
          maxSize: PaneSize.pixel(_sidebarMaxWidth),
        ),
        PaneEntry(id: 'content', initialSize: PaneSize.fraction(1)),
      ],
    );
    _settings.addListener(_syncTerminalTheme);
    // 启动即创建首个标签；焦点由 provider 在标签建好后授予。
    unawaited(_provider.createTab());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 跟随的是应用主题解析后的深浅色，而不是裸的系统亮度：
    // 颜色模式为深/浅时，MaterialApp 的实际主题就是对应的亮度。
    _appBrightness = Theme.of(context).brightness;
    _syncTerminalTheme();
  }

  @override
  void dispose() {
    _settings.removeListener(_syncTerminalTheme);
    _panes.dispose();
    super.dispose();
  }

  /// 偏好或应用主题深浅变化时，同步到所有已打开的会话。
  void _syncTerminalTheme() {
    _provider.updateTerminalTheme(_settings.terminalThemeFor(_appBrightness));
  }

  void _createTab() {
    if (_provider.isCreating) return;
    unawaited(_provider.createTab());
  }

  void _openSettings() {
    unawaited(showSettingsDialog<void>(context));
  }

  @override
  Widget build(BuildContext context) {
    // 返回键不退出应用；抽屉、对话框属于独立路由，返回仍会先关闭它们。
    return PopScope(
      canPop: false,
      child: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          final wide =
              MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;
          return wide ? _buildWide(context) : _buildNarrow(context);
        },
      ),
    );
  }

  /// 宽屏与抽屉共用的同一个侧边栏实例配置。
  Widget _buildSidebar() {
    return TerminalSidebar(
      provider: _provider,
      onTabSelected: _provider.selectTab,
      onOpenSettings: _openSettings,
    );
  }

  Widget _buildWide(BuildContext context) {
    return Scaffold(
      body: MultiPane(
        direction: Axis.horizontal,
        controller: _panes,
        paneBuilder: (context, id, animationProgress) => switch (id) {
          'sidebar' => _buildSidebar(),
          _ => _Workspace(provider: _provider),
        },
      ),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_provider.activeTab?.title ?? '终端'),
        actions: [
          IconButton(
            onPressed: _provider.isCreating ? null : _createTab,
            icon: const Icon(Icons.add),
            tooltip: '新建终端',
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
          ),
        ],
      ),
      drawer: Drawer(width: _sidebarInitialWidth, child: _buildSidebar()),
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
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.terminal, size: 48, color: scheme.onSurfaceVariant),
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
