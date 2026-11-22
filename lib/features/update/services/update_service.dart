import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../models/update_info.dart';

/// 通过 GitHub Release 检查更新。
///
/// 本地版本来自 `pubspec.yaml` 的 `version`（去掉 `+build`），远端版本是
/// 仓库最新正式 Release 的 tag（形如 `v0.2.0`），两者按语义化版本比较。
class UpdateService {
  const UpdateService._();

  /// 本应用仓库；Release 由 `.github/workflows/release.yml` 生成。
  static const String repository = 'qinshah/t';

  static const String _apiBase = 'https://api.github.com/repos/$repository';
  static const String _latestPage =
      'https://github.com/$repository/releases/latest';

  /// 检查最新版本。
  ///
  /// 仓库还没有正式 Release 时返回 `null`；网络或接口异常时抛出异常。
  static Future<UpdateCheckResult?> check() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final release = await _fetchLatestRelease();
    if (release == null) return null;

    final tag = release['tag_name'];
    if (tag is! String || tag.isEmpty) return null;

    final assets = release['assets'];
    return UpdateCheckResult(
      currentVersion: packageInfo.version,
      latestTag: tag,
      releaseUrl: release['html_url'] as String? ?? _latestPage,
      downloadUrl: assets is List ? pickDownloadUrl(assets) : null,
      notes: (release['body'] as String? ?? '').trim(),
    );
  }

  /// 请求 `releases/latest`；404 表示还没有发布过正式 Release。
  static Future<Map<String, dynamic>?> _fetchLatestRelease() async {
    final response = await http
        .get(
          Uri.parse('$_apiBase/releases/latest'),
          headers: const {
            // GitHub API 要求带 UA；Accept 固定 v3 JSON。
            'User-Agent': 't-update-checker',
            'Accept': 'application/vnd.github+json',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw http.ClientException('GitHub API ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  /// 按平台挑安装包；命名规则见 `.github/workflows/release.yml`。
  ///
  /// [platform] 仅供测试注入；默认取 [defaultTargetPlatform]。
  static String? pickDownloadUrl(
    List<dynamic> assets, {
    TargetPlatform? platform,
  }) {
    if (kIsWeb) return null;

    final matches = switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.android => (String name) => name.endsWith('.apk'),
      TargetPlatform.windows => (
        String name,
      ) => name.endsWith('.zip') && name.contains('windows'),
      TargetPlatform.macOS => (
        String name,
      ) => name.endsWith('.zip') && name.contains('macos'),
      TargetPlatform.linux => (
        String name,
      ) => name.endsWith('.zip') && name.contains('linux'),
      _ => null,
    };
    if (matches == null) return null;

    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is String && url is String && matches(name)) return url;
    }
    return null;
  }
}
