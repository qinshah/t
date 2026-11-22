import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 偏好项的底层存储。
///
/// 内存里维护一个 `Map<String, Object?>`，只存基本类型（`String` / `bool`
/// / `num`）。启动时一次读入，写入即时更新内存并异步落盘，因此
/// [get] 可以同步读取。
class SettingsStore {
  /// 创建落盘到应用支持目录的存储。
  SettingsStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  /// 仅内存存储，主要用于组件测试。
  SettingsStore.memory() : _directoryProvider = null;

  /// 偏好文件名。
  static const fileName = 'preferences.json';

  final Future<Directory> Function()? _directoryProvider;
  final Map<String, Object?> _values = <String, Object?>{};

  /// 串行化写入，避免连续修改时两次写入交错。
  Future<void> _pending = Future<void>.value();

  /// 从磁盘读取；文件不存在、解析失败或目录不可用时保持空表。
  Future<void> load() async {
    final directoryProvider = _directoryProvider;
    if (directoryProvider == null) return;
    try {
      final file = await _file(directoryProvider);
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return;
      _values
        ..clear()
        ..addAll(decoded.cast<String, Object?>());
    } catch (error, stackTrace) {
      debugPrint('SettingsStore: 读取偏好失败: $error\n$stackTrace');
    }
  }

  /// 同步读取一个偏好值；类型不符或不存在时返回 `null`。
  V? get<V>(String key) {
    final value = _values[key];
    return value is V ? value : null;
  }

  /// 写入一个偏好值并异步落盘。
  Future<void> put(String key, Object? value) {
    _values[key] = value;
    return _save();
  }

  /// 删除一个偏好值并异步落盘。
  Future<void> remove(String key) {
    _values.remove(key);
    return _save();
  }

  /// 等待已排队的写入全部完成。
  Future<void> flush() => _pending;

  Future<void> _save() {
    final directoryProvider = _directoryProvider;
    if (directoryProvider == null) return Future<void>.value();
    _pending = _pending.then((_) async {
      try {
        final file = await _file(directoryProvider);
        const encoder = JsonEncoder.withIndent('  ');
        await file.writeAsString(encoder.convert(_values));
      } catch (error, stackTrace) {
        debugPrint('SettingsStore: 保存偏好失败: $error\n$stackTrace');
      }
    });
    return _pending;
  }

  Future<File> _file(Future<Directory> Function() directoryProvider) async {
    final directory = await directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }
}
