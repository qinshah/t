import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:t/features/settings/models/app_preferences.dart';
import 'package:t/features/settings/providers/settings_provider.dart';
import 'package:t/features/settings/services/preferences_store.dart';
import 'package:t/features/settings/widgets/settings_dialog.dart';

/// 不落盘的存储实现。
///
/// 组件测试运行在 FakeAsync 区域，真实文件 I/O 的 Future 不会推进；
/// 这里覆写 [save] 让设置修改只留在内存里。
class _NoopPreferencesStore extends PreferencesStore {
  _NoopPreferencesStore()
    : super(directoryProvider: () async => Directory.systemTemp);

  @override
  Future<void> save(AppPreferences preferences) async {}
}

void main() {
  late SettingsProvider settings;

  setUp(() {
    settings = SettingsProvider(
      store: _NoopPreferencesStore(),
      initial: const AppPreferences(),
    );
  });

  tearDown(() {
    settings.dispose();
  });

  Widget host() {
    return ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showSettingsDialog<void>(context),
                child: const Text('打开设置'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle();
  }

  testWidgets('宽屏使用不占满的对话框，并展示两个配置项', (tester) async {
    await tester.pumpWidget(host());
    await openDialog(tester);

    expect(find.text('颜色模式'), findsOneWidget);
    expect(find.text('终端配色'), findsOneWidget);
    expect(find.text('终端深浅'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    // 宽屏对话框有最大尺寸约束，不是 fullscreen 的零内边距。
    expect(tester.widget<Dialog>(find.byType(Dialog)).insetPadding, isNull);
    // 默认值下没有恢复按钮。
    expect(find.byTooltip('恢复默认'), findsNothing);
  });

  testWidgets('窄屏去掉内边距铺满窗口', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await openDialog(tester);

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.insetPadding, EdgeInsets.zero);
    // 铺满窗口时必须是直角。
    final shape = dialog.shape;
    expect(shape, isA<RoundedRectangleBorder>());
    expect((shape as RoundedRectangleBorder).borderRadius, BorderRadius.zero);
    expect(find.text('颜色模式'), findsOneWidget);
    expect(find.text('终端深浅'), findsOneWidget);
  });

  testWidgets('对话框打开后跨过断点会实时切换形态', (tester) async {
    await tester.pumpWidget(host());
    await openDialog(tester);
    expect(tester.widget<Dialog>(find.byType(Dialog)).insetPadding, isNull);

    // 不关闭对话框，直接把窗口缩到断点以下。
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();

    expect(
      tester.widget<Dialog>(find.byType(Dialog)).insetPadding,
      EdgeInsets.zero,
    );
    final narrowShape = tester.widget<Dialog>(find.byType(Dialog)).shape;
    expect(narrowShape, isA<RoundedRectangleBorder>());
    expect(
      (narrowShape as RoundedRectangleBorder).borderRadius,
      BorderRadius.zero,
    );
    expect(find.text('终端深浅'), findsOneWidget);

    // 再拉宽，应该恢复成不占满、带默认圆角的对话框。
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    final wideDialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(wideDialog.insetPadding, isNull);
    expect(wideDialog.shape, isNull);
  });

  testWidgets('修改后出现恢复按钮，点击回到默认', (tester) async {
    await tester.pumpWidget(host());
    await openDialog(tester);

    // 颜色模式行在第一位，两个分段控件都含「深色」，这里点第一处。
    await tester.tap(find.text('深色').first);
    await tester.pumpAndSettle();
    expect(settings.colorMode, AppColorMode.dark);
    expect(find.byTooltip('恢复默认'), findsOneWidget);

    settings.setTerminalBrightness(TerminalBrightness.light);
    await tester.pump();
    expect(find.byTooltip('恢复默认'), findsNWidgets(2));

    await tester.tap(find.byTooltip('恢复默认').first);
    await tester.pumpAndSettle();
    expect(settings.colorMode, AppColorMode.auto);
    expect(settings.terminalBrightness, TerminalBrightness.light);
    expect(find.byTooltip('恢复默认'), findsOneWidget);
  });
}
