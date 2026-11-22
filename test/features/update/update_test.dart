import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:t/features/update/models/update_info.dart';
import 'package:t/features/update/services/update_service.dart';

void main() {
  group('compareVersions', () {
    test('版本相同时返回 0', () {
      expect(compareVersions('0.1.0', '0.1.0'), 0);
      expect(compareVersions('v0.1.0', '0.1.0'), 0);
    });

    test('忽略 v 前缀与 +build 后缀', () {
      expect(compareVersions('v0.2.0', '0.1.0+3'), greaterThan(0));
      expect(compareVersions('0.1.0+9', 'v0.1.0+1'), 0);
    });

    test('按数值而不是字符串比较每一段', () {
      expect(compareVersions('0.10.0', '0.2.0'), greaterThan(0));
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
    });

    test('缺失的段按 0 处理', () {
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('1.0.1', '1.0'), greaterThan(0));
    });

    test('无法识别的段按 0 处理，不抛异常', () {
      expect(compareVersions('1.x.0', '1.0.0'), 0);
      expect(compareVersions('', '0.0.0'), 0);
    });
  });

  group('UpdateCheckResult.hasUpdate', () {
    UpdateCheckResult result(String currentVersion, String latestTag) {
      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestTag: latestTag,
        releaseUrl: 'https://github.com/qinshah/t/releases/latest',
        downloadUrl: null,
        notes: '',
      );
    }

    test('远端 tag 更新时为 true', () {
      expect(result('0.1.0', 'v0.2.0').hasUpdate, isTrue);
    });

    test('版本相同或更旧时为 false', () {
      expect(result('0.2.0', 'v0.2.0').hasUpdate, isFalse);
      expect(result('0.3.0', 'v0.2.0').hasUpdate, isFalse);
    });
  });

  group('pickDownloadUrl', () {
    const assets = [
      {
        'name': 't-v0.2.0-android.apk',
        'browser_download_url': 'https://example.com/android.apk',
      },
      {
        'name': 't-v0.2.0-windows.zip',
        'browser_download_url': 'https://example.com/windows.zip',
      },
      {
        'name': 't-v0.2.0-macos.zip',
        'browser_download_url': 'https://example.com/macos.zip',
      },
      {
        'name': 't-v0.2.0-linux.zip',
        'browser_download_url': 'https://example.com/linux.zip',
      },
      {
        'name': 'release-notes.txt',
        'browser_download_url': 'https://example.com/notes.txt',
      },
    ];

    test('Android 选 apk', () {
      expect(
        UpdateService.pickDownloadUrl(assets, platform: TargetPlatform.android),
        'https://example.com/android.apk',
      );
    });

    test('桌面平台按文件名关键字选 zip', () {
      expect(
        UpdateService.pickDownloadUrl(assets, platform: TargetPlatform.macOS),
        'https://example.com/macos.zip',
      );
      expect(
        UpdateService.pickDownloadUrl(assets, platform: TargetPlatform.windows),
        'https://example.com/windows.zip',
      );
      expect(
        UpdateService.pickDownloadUrl(assets, platform: TargetPlatform.linux),
        'https://example.com/linux.zip',
      );
    });

    test('没有匹配资产时返回 null', () {
      expect(
        UpdateService.pickDownloadUrl(const [
          {
            'name': 'release-notes.txt',
            'browser_download_url': 'https://example.com/notes.txt',
          },
        ], platform: TargetPlatform.macOS),
        isNull,
      );
      expect(
        UpdateService.pickDownloadUrl(assets, platform: TargetPlatform.iOS),
        isNull,
      );
    });

    test('忽略格式异常的资产条目', () {
      expect(
        UpdateService.pickDownloadUrl(const [
          'not-a-map',
          {'name': 't-v0.2.0-macos.zip'},
          {'browser_download_url': 'https://example.com/macos.zip'},
          {
            'name': 't-v0.2.0-macos.zip',
            'browser_download_url': 'https://example.com/macos.zip',
          },
        ], platform: TargetPlatform.macOS),
        'https://example.com/macos.zip',
      );
    });
  });
}
