/// 一次更新检查的结果。
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestTag,
    required this.releaseUrl,
    required this.downloadUrl,
    required this.notes,
  });

  /// 当前安装的应用版本，如 `0.1.0`。
  final String currentVersion;

  /// GitHub Release 的 tag，如 `v0.2.0`。
  final String latestTag;

  /// Release 页面；没有匹配的安装包时用它兜底。
  final String releaseUrl;

  /// 当前平台安装包直链；Release 未附带对应资产时为空。
  final String? downloadUrl;

  /// Release 更新说明。
  final String notes;

  /// 远端版本是否比当前版本新。
  bool get hasUpdate => compareVersions(latestTag, currentVersion) > 0;
}

/// 语义化版本比较：正数表示 a 比 b 新，0 表示相同。
///
/// 忽略 `v` 前缀与 `+build` 后缀，缺失的段按 0 处理（`1.0` 等价 `1.0.0`）。
int compareVersions(String a, String b) {
  final pa = _segments(a);
  final pb = _segments(b);
  final length = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < length; i++) {
    final na = i < pa.length ? pa[i] : 0;
    final nb = i < pb.length ? pb[i] : 0;
    if (na != nb) return na - nb;
  }
  return 0;
}

/// 取出每段开头的数字，无法识别的段按 0 处理，避免手改配置导致崩溃。
List<int> _segments(String version) {
  final core = version
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('+')
      .first;
  return [
    for (final part in core.split('.'))
      int.tryParse(RegExp(r'^\d+').stringMatch(part) ?? '') ?? 0,
  ];
}
