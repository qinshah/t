---
name: update-check
description: t 项目（Flutter）的应用内检查更新功能：启动时静默检查 + 设置里手动检查，用本地版本对比 GitHub Release tag，下载走系统浏览器。当用户要求"检查更新/版本检查/更新提示/接入 GitHub Release 更新"或修改相关逻辑时使用。
---

# 检查更新功能

基于 GitHub Release API，不依赖商店。版本对比成功后用外部浏览器打开安装包链接。

## 代码位置

| 文件 | 作用 |
|------|------|
| `lib/features/update/models/update_info.dart` | `UpdateCheckResult` 与语义化版本比较 `compareVersions` |
| `lib/features/update/services/update_service.dart` | 请求 `releases/latest`、读取本地版本、按平台挑安装包 |
| `lib/features/update/widgets/update_prompt.dart` | 检查入口、更新对话框、外部浏览器打开链接 |
| `lib/app.dart` | 启动后首帧触发一次静默检查 |
| `lib/features/settings/widgets/settings_dialog.dart` | 设置页「检查更新」手动入口 |

## 行为

- 本地版本：`package_info_plus` 的 `PackageInfo.fromPlatform().version`，
  即 `pubspec.yaml` 的 `version`（不含 `+build`）。
- 远端版本：`https://api.github.com/repos/qinshah/t/releases/latest` 的 `tag_name`（如 `v0.2.0`）。
- 比较：去掉 `v` 前缀后逐段数字比较，缺失段按 0（`1.0` == `1.0.0`）。
- 启动检查：`TerminalApp.initState` 的 post-frame 回调调用
  `checkForUpdates(navigator: rootNavigatorKey.currentState)`；失败静默，只有
  发现新版本才弹窗。
- 手动检查：设置对话框底部「检查更新」，`manual: true`，对"已是最新 / 失败"
  弹出结果提示。
- 下载：按当前平台在 Release assets 里找第一个匹配项，用
  `url_launcher` 的 `LaunchMode.externalApplication` 在系统浏览器打开：
  - Android：按 `device_info_plus` 读到的 `supportedAbis` 匹配
    `.apk` 文件名中的 `arm64-v8a` / `x86_64`；旧 Release 没有拆分时退回
    第一个 `.apk`
  - macOS：`.zip` 且文件名含 `macos`
  - Windows：`.zip` 且文件名含 `windows`
  - Linux：`.zip` 且文件名含 `linux`
  - 没有匹配资产时打开 Release 页面。
- 并发保护：`_checking` 防止启动检查与手动检查重复请求；`_dialogOpen`
  防止对话框叠加。

## 维护规则

- 对话框必须用 `DialogRoute` push 到根 Navigator，**不要用 `showDialog`**：
  当前 Flutter SDK 在 macOS 上会尝试创建原生窗口并触发
  `Multiview can only be enabled before adding any view controllers` 崩溃
  （与 `settings_dialog.dart` 的约定一致）。
- 换仓库只改 `UpdateService.repository`。
- 修改 Release 产物命名时同步更新 `pickDownloadUrl` 与
  [release skill](../release/SKILL.md) 的命名约定；Android 产物是
  `t-vX.Y.Z-android-<abi>.apk`，`abi` 只有 `arm64-v8a` / `x86_64`。
- Android release 清单必须声明 `android.permission.INTERNET`，否则正式包
  无法请求 GitHub API（debug/profile 清单自带，但 release 不会合并进来）。
- GitHub API 需要 `User-Agent` 请求头，接口限流 60 次/小时/IP；不要把检查
  放到高频路径。
- `/releases/latest` 不返回 draft 或 prerelease：发版后必须把草稿 Release
  转为正式版并设为 latest，否则用户检查不到新版本。
- 网络失败只 `debugPrint`，不打断启动。

## 验证

```bash
flutter analyze
flutter test test/features/update test/features/settings
```

改动版本比较或资产匹配时，优先补不依赖网络的单元测试（`compareVersions`、
`pickDownloadUrl`）。
