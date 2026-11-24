import 'package:flutter/material.dart' show ThemeMode;

import '../services/settings_store.dart';

/// 终端字号：默认值、允许范围（4–64，步进 1）。
const int defaultTerminalFontSize = 16;
const int minTerminalFontSize = 4;
const int maxTerminalFontSize = 64;

/// 设置项分组，供设置页按分类展示。
enum SettingCategory {
  def('默认'),
  appearance('外观'),
  terminal('终端');

  final String title;

  const SettingCategory(this.title);
}

/// 全部偏好项的名称与展示标题。
enum SettingEnum {
  themeMode('深色模式', category: SettingCategory.appearance),
  terminalThemeMode('终端深色模式', category: SettingCategory.terminal),
  terminalFontSize('终端字号', category: SettingCategory.terminal),
  quitWhenLastClosed('自动退出', category: SettingCategory.terminal);

  final String title;
  final SettingCategory category;

  const SettingEnum(this.title, {this.category = SettingCategory.def});
}

/// 单个偏好项。
///
/// 参考 flutter_bili 的 `Setting` 写法：静态实例自带默认值，
/// `get` 读当前值，`set` 在等于默认值时直接删除存储项。
/// 持久化只存基本类型，复杂值通过 [enCoder] / [deCoder] 转换。
class Setting<Value, Data> {
  Setting._(this.item, {required this.defValue, this.enCoder, this.deCoder}) {
    values.add(this);
  }

  /// 当前使用的存储；`main` 在读取磁盘后替换，测试可换成内存实现。
  static SettingsStore store = SettingsStore.memory();

  /// 该项对应的枚举，其 `name` 就是 JSON 的 key。
  final SettingEnum item;

  /// 默认值；恢复默认即删除存储项。
  final Value defValue;

  /// 值 -> 基本类型。
  final Data Function(Value value)? enCoder;

  /// 基本类型 -> 值。
  final Value Function(Data data)? deCoder;

  /// 删除存储项，回到默认值。
  Future<void> reset() => store.remove(item.name);

  /// 读取当前值；没有存储项时返回 `null`。
  Value? maybeGet() {
    final data = store.get<Data>(item.name);
    if (data == null) return null;
    return deCoder == null ? data as Value : deCoder!(data);
  }

  /// 读取当前值，缺失时返回 [defValue]。
  Value get() => maybeGet() ?? defValue;

  /// 是否仍为默认值。
  bool get isDefault => get() == defValue;

  /// 写入新值；等于默认值时改走 [reset]。
  Future<void> set(Value value) {
    if (value == defValue) return reset();
    return store.put(item.name, enCoder?.call(value) ?? value);
  }

  static final values = <Setting<dynamic, dynamic>>[];

  /// 界面深浅色模式。
  static final themeMode = Setting<ThemeMode, String>._(
    SettingEnum.themeMode,
    defValue: ThemeMode.system,
    enCoder: (value) => value.name,
    deCoder: _themeModeFromName,
  );

  /// 终端配色深浅；自动时跟随应用主题亮度。
  static final terminalThemeMode = Setting<ThemeMode, String>._(
    SettingEnum.terminalThemeMode,
    defValue: ThemeMode.system,
    enCoder: (value) => value.name,
    deCoder: _themeModeFromName,
  );

  /// 终端字号（逻辑像素，整数）；设置页、Ctrl 快捷键与手势共用。
  static final terminalFontSize = Setting<int, num>._(
    SettingEnum.terminalFontSize,
    defValue: defaultTerminalFontSize,
    // JSON 里的整数可能被解码成 double，统一取整再使用。
    deCoder: (value) => value.round(),
  );

  /// 关闭最后一个终端后是否退出应用。
  static final quitWhenLastClosed = Setting<bool, bool>._(
    SettingEnum.quitWhenLastClosed,
    defValue: true,
  );
}

/// 名称转 [ThemeMode]；未知值回退自动，避免配置文件被手改坏后启动失败。
ThemeMode _themeModeFromName(String name) {
  for (final mode in ThemeMode.values) {
    if (mode.name == name) return mode;
  }
  return ThemeMode.system;
}

/// 设置界面上的中文标签。
extension ThemeModeLabel on ThemeMode {
  /// 自动 / 暗色 / 亮色。
  String get label => switch (this) {
    ThemeMode.system => '自动',
    ThemeMode.dark => '暗色',
    ThemeMode.light => '亮色',
  };
}
