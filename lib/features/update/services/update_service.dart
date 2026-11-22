import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
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
      downloadUrl: assets is List
          ? pickDownloadUrl(assets, androidAbi: await _androidAbi())
          : null,
      notes: (release['body'] as String? ?? '').trim(),
    );
  }

  /// Android 设备优先使用的 ABI；其他平台返回 `null`。
  ///
  /// Release 里的 APK 按 ABI 拆分（仅 arm64-v8a / x86_64），需要按设备选对包。
  static Future<String?> _androidAbi() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final abis = (await DeviceInfoPlugin().androidInfo).supportedAbis;
      for (final abi in const ['arm64-v8a', 'x86_64']) {
        if (abis.contains(abi)) return abi;
      }
    } catch (error) {
      debugPrint('读取 Android ABI 失败: $error');
    }
    return null;
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
  /// [platform] 与 [androidAbi] 仅供测试注入。
  static String? pickDownloadUrl(
    List<dynamic> assets, {
    TargetPlatform? platform,
    String? androidAbi,
  }) {
    if (kIsWeb) return null;

    final target = platform ?? defaultTargetPlatform;
    if (target == TargetPlatform.android) {
      // 优先匹配当前 ABI；旧 Release 没有拆分时退回第一个 apk。
      if (androidAbi != null) {
        final byAbi = _findUrl(
          assets,
          (name) => name.endsWith('.apk') && name.contains(androidAbi),
        );
        if (byAbi != null) return byAbi;
      }
      return _findUrl(assets, (name) => name.endsWith('.apk'));
    }

    final matches = switch (target) {
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
    return _findUrl(assets, matches);
  }

  static String? _findUrl(
    List<dynamic> assets,
    bool Function(String name) matches,
  ) {
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is String && url is String && matches(name)) return url;
    }
    return null;
  }
}
