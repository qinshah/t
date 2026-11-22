import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_preferences.dart';

/// 偏好文件的读写层。
///
/// 文件放在应用支持目录下的 `preferences.json`。所有异常都在内部消化：
/// 读取失败回退默认值，写入失败只记录日志，不能因为偏好问题影响终端启动。
class PreferencesStore {
  /// 创建存储层。
  ///
  /// [directoryProvider] 仅供测试注入临时目录；生产使用
  /// `path_provider` 的 `getApplicationSupportDirectory`。
  PreferencesStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;

  /// 串行化写入，避免连续切换设置时两次写入交错。
  Future<void> _pending = Future<void>.value();

  /// 偏好文件名。
  static const fileName = 'preferences.json';

  /// 读取偏好；文件不存在、解析失败或目录不可用时返回默认值。
  Future<AppPreferences> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const AppPreferences();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return const AppPreferences();
      return AppPreferences.fromJson(decoded.cast<String, Object?>());
    } catch (error, stackTrace) {
      debugPrint('PreferencesStore: 读取偏好失败: $error\n$stackTrace');
      return const AppPreferences();
    }
  }

  /// 保存偏好；失败只记日志。
  Future<void> save(AppPreferences preferences) {
    _pending = _pending.then((_) async {
      try {
        final file = await _file();
        const encoder = JsonEncoder.withIndent('  ');
        await file.writeAsString(encoder.convert(preferences.toJson()));
      } catch (error, stackTrace) {
        debugPrint('PreferencesStore: 保存偏好失败: $error\n$stackTrace');
      }
    });
    return _pending;
  }

  /// 等待已排队的写入全部完成。
  ///
  /// 主要供测试在清理临时目录前调用，避免删除与异步写入竞争。
  Future<void> flush() => _pending;

  /// 解析偏好文件位置，必要时创建目录。
  Future<File> _file() async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }
}
