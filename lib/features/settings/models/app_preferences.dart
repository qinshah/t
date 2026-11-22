import 'package:flutter/foundation.dart';

/// 应用外观颜色模式。
///
/// 对应 `MaterialApp.themeMode`：自动跟随系统、强制深色、强制浅色。
enum AppColorMode {
  /// 跟随系统亮度。
  auto('自动'),

  /// 始终使用深色主题。
  dark('深色'),

  /// 始终使用浅色主题。
  light('浅色');

  const AppColorMode(this.label);

  /// 设置界面上展示的中文名称。
  final String label;
}

/// 终端 ANSI 配色预制。
///
/// 只描述「用哪套色板」，深浅由 [TerminalBrightness] 单独控制。
enum TerminalPalette {
  /// Solarized 配色，默认。
  solarized('Solarized');

  const TerminalPalette(this.label);

  /// 设置界面上展示的名称。
  final String label;
}

/// 终端配色深浅。
///
/// 与 [AppColorMode] 独立：可以跟随界面颜色（默认），也可以强制深/浅。
enum TerminalBrightness {
  /// 跟随当前应用主题的深浅色。
  followColorMode('随颜色'),

  /// 始终使用深色终端配色。
  dark('深色'),

  /// 始终使用浅色终端配色。
  light('浅色');

  const TerminalBrightness(this.label);

  /// 设置界面上展示的中文名称。
  final String label;
}

/// 全部偏好的默认值。
///
/// 集中放在静态属性里，设置界面据此判断某一项是否被改动过，
/// 并决定是否显示「恢复默认」按钮。
abstract final class AppDefaults {
  /// 默认跟随系统亮度。
  static const AppColorMode colorMode = AppColorMode.auto;

  /// 默认使用 Solarized 配色。
  static const TerminalPalette terminalPalette = TerminalPalette.solarized;

  /// 默认跟随界面颜色。
  static const TerminalBrightness terminalBrightness =
      TerminalBrightness.followColorMode;
}

/// 需要持久化的用户偏好快照。
///
/// 不可变对象；每次修改由 [copyWith] 生成新实例，方便 `ChangeNotifier`
/// 判断是否需要通知与落盘。
@immutable
class AppPreferences {
  /// 创建偏好快照；未指定的项取 [AppDefaults]。
  const AppPreferences({
    this.colorMode = AppDefaults.colorMode,
    this.terminalPalette = AppDefaults.terminalPalette,
    this.terminalBrightness = AppDefaults.terminalBrightness,
  });

  /// 从 JSON 恢复偏好。
  ///
  /// 未知枚举值、缺失字段或类型不符都回退到默认值，保证配置文件
  /// 被手改坏时应用仍能启动。旧版本把深浅写进 `terminalPalette`
  /// （`solarizedLight` / `solarizedDark`），这里一并兼容。
  factory AppPreferences.fromJson(Map<String, Object?> json) {
    return AppPreferences(
      colorMode: _enumByName(
        AppColorMode.values,
        json['colorMode'],
        AppDefaults.colorMode,
      ),
      terminalPalette: _parsePalette(json['terminalPalette']),
      terminalBrightness: _enumByName(
        TerminalBrightness.values,
        json['terminalBrightness'],
        AppDefaults.terminalBrightness,
      ),
    );
  }

  /// 外观颜色模式。
  final AppColorMode colorMode;

  /// 终端配色预制。
  final TerminalPalette terminalPalette;

  /// 终端配色深浅。
  final TerminalBrightness terminalBrightness;

  /// 复制一份并替换指定字段。
  AppPreferences copyWith({
    AppColorMode? colorMode,
    TerminalPalette? terminalPalette,
    TerminalBrightness? terminalBrightness,
  }) {
    return AppPreferences(
      colorMode: colorMode ?? this.colorMode,
      terminalPalette: terminalPalette ?? this.terminalPalette,
      terminalBrightness: terminalBrightness ?? this.terminalBrightness,
    );
  }

  /// 序列化为可写入 JSON 的 Map。
  Map<String, Object?> toJson() {
    return {
      // 第二版拆出了 terminalBrightness。
      'version': 2,
      'colorMode': colorMode.name,
      'terminalPalette': terminalPalette.name,
      'terminalBrightness': terminalBrightness.name,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is AppPreferences &&
        other.colorMode == colorMode &&
        other.terminalPalette == terminalPalette &&
        other.terminalBrightness == terminalBrightness;
  }

  @override
  int get hashCode =>
      Object.hash(colorMode, terminalPalette, terminalBrightness);

  @override
  String toString() =>
      'AppPreferences(colorMode: ${colorMode.name}, '
      'terminalPalette: ${terminalPalette.name}, '
      'terminalBrightness: ${terminalBrightness.name})';
}

/// 解析配色名；旧版本的 `solarizedLight` / `solarizedDark` 都归到
/// [TerminalPalette.solarized]。
TerminalPalette _parsePalette(Object? raw) {
  if (raw == 'solarizedLight' || raw == 'solarizedDark') {
    return TerminalPalette.solarized;
  }
  return _enumByName(TerminalPalette.values, raw, AppDefaults.terminalPalette);
}

/// 按枚举名解析，找不到或类型不符时返回 [fallback]。
T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
