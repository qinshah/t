---
name: release
description: t 项目（Flutter 多标签终端）的发版流程：修改 pubspec 版本号、打 tag、推送触发 GitHub Actions 构建 Android/Windows/macOS 产物并生成 Release。当用户要求"发版/发布新版本/打 tag/跑 release workflow"时使用。
---

# t 发版流程

发布由 [.github/workflows/release.yml](../../../.github/workflows/release.yml) 驱动：
推送 `v*` tag 即触发构建，产物汇总后创建 **draft** GitHub Release。
工作流不含 Rust 构建步骤（本项目没有 Rust 依赖）。

## 关键约定：版本号必须与 tag 一致

应用内「检查更新」用 `package_info_plus` 读到的版本（来自 `pubspec.yaml`）
与 Release tag 比较。所以：

- `pubspec.yaml` 的 `version: 0.1.0+1` → tag 必须是 `v0.1.0`（`+1` 为构建号，不参与比较）。
- workflow 的 `prepare` job 会校验两者，不一致直接失败。

## 关键约定：CI 的 Flutter 版本必须满足 pubspec 的 SDK 约束

改 workflow 或升级依赖前，先核对两条约束：

```bash
sed -n '/^environment:/,/^[^ ]/p' pubspec.yaml   # sdk 约束，当前 ^3.13.5
flutter --version                                # 本地 Flutter / Dart 版本
```

- workflow 的 `FLUTTER_VERSION` 自带 Dart 必须满足 `environment.sdk`，同时满足
  `ghostty_dart_flutter` 的 `flutter >= 3.47.0`，取两者较高者。
- 已知对应关系：Flutter 3.47.3 → Dart 3.13.3（**不满足** `^3.13.5`）；
  Flutter 3.50.1 → Dart 3.13.5。当前固定 **3.50.1**。
- 只升 Flutter、不要为了过 CI 调低 pubspec 的 SDK 约束。
- Android 还有独立的最低工具链版本：Flutter 3.50.1 要求 AGP ≥ 9.1.1
  （`android/settings.gradle.kts` 的 `com.android.application`），并保持
  `android/gradle/wrapper` 的 Gradle 版本兼容。
- CI 日志出现 `The current Dart SDK version is ... Because t requires SDK
  version ^X, version solving failed`，就是 Flutter 版本不够：先改
  `FLUTTER_VERSION`，再重跑。
- 升级 Flutter 版本后先本地 `flutter pub get`、`flutter analyze`、
  `flutter test`，再发版。

## 发版步骤

### 1. 确定新版本号

```bash
git tag -l | tail -5          # 上一个版本
git log v上一个tag..HEAD --oneline   # 区间内提交
```

按变更规模决定 patch / minor / major，更新 `pubspec.yaml`：

```yaml
version: 0.2.0+2   # 版本号 + 递增的构建号
```

Flutter 会据此自动生成 Android `versionName`/`versionCode` 与 macOS
`CFBundleShortVersionString`，不需要改原生工程文件。

### 2. 提交版本变更

```bash
git add pubspec.yaml
git commit -m "chore(release): 发布 v0.2.0"
git push origin main
```

### 3. 生成 tag 信息

从上一个 tag 到 HEAD 的提交按模块归类，写成用户视角的更新日志
（bug 修复写"修复了 XX"，不要照抄 commit）：

```bash
git log v0.1.0..HEAD --oneline
git tag -a v0.2.0 -m "v0.2.0 更新内容

终端
- ...
设置
- ..."
```

### 4. 推送 tag 触发 CI

```bash
git push origin v0.2.0
```

也可在 GitHub Actions 页面手动 `workflow_dispatch`，tag 留空则取仓库最新 tag。
手动填写不存在的 tag 时，CI 会在当前提交上创建它。

### 5. 验证 CI

```bash
gh run list --repo qinshah/t --limit 3
gh run watch <id> --repo qinshah/t --exit-status
gh run view <id> --repo qinshah/t --log-failed   # 失败时
```

构建 job：`android`（APK）、`windows`（zip）、`macos`（zip），三者都成功后
`release` job 创建草稿。产物命名（应用内按此匹配平台，不要随意改名）：

```
t-v0.2.0-android.apk
t-v0.2.0-windows.zip
t-v0.2.0-macos.zip
```

### 6. 发布 Release（草稿 → 正式）

`/releases/latest` 不返回草稿，未发布的版本应用检查不到。确认产物后：

```bash
gh release edit v0.2.0 --repo qinshah/t --draft=false --latest
gh release list --repo qinshah/t --limit 3
```

## 版本不匹配排查

- **`Because t requires SDK version ^X, version solving failed`**：CI 的
  Flutter 自带 Dart 低于 pubspec 要求，升级 `FLUTTER_VERSION`。
- **`Android Gradle Plugin version X is lower than Flutter's minimum supported
  version Y`**：升级 `android/settings.gradle.kts` 的 `com.android.application`
  到要求的最低版本（3.50.1 需要 ≥ 9.1.1），并确认 Gradle wrapper 兼容。
- 改完重新提交、重新打 tag 触发构建；本地可先跑
  `flutter build apk --release` 验证。

## 注意事项

- 发版前 `git status` 确认工作区干净；`third/ghostty_dart` 子模块不要有未提交改动。
- CI 用 `submodules: recursive` 拉取 `third/ghostty_dart`，子模块改动需先推到
  `qinshah/ghostty_dart`。
- `PUB_HOSTED_URL` 固定为 `https://pub.flutter-io.cn`，与 `pubspec.lock` 生成环境一致。
- Flutter 版本固定在 workflow 的 `FLUTTER_VERSION`（当前 3.50.1），
  必须满足 `pubspec.yaml` 的 `sdk ^3.13.5` 与 `ghostty_dart_flutter` 的
  `flutter >= 3.47.0`。
- 只有正式（非 draft、非 prerelease）Release 会被应用内检查更新看到。
