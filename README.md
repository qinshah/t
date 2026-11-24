# t

一个基于 Flutter 的多标签桌面终端：**ghostty_dart_flutter**（libghostty-vt，
Ghostty 的终端引擎）负责解析与渲染，**flutter_pty_new** 负责本地 PTY。

## 当前功能

- 多终端标签：侧边栏（宽屏）或侧边抽屉（窄屏）管理，可新建、切换、关闭，
  标签数量不限。
- 每个标签是一个独立的真实 PTY 会话；所有会话常驻 widget 树（`IndexedStack`
  保活），切换标签不会中断运行中的命令，也不会丢滚动缓冲。
- 关闭标签时终止对应 Shell；全部标签关闭后显示空状态，可重新新建。
- 终端能力来自 libghostty-vt：ANSI / 真彩色、全屏程序（`vim`、`top`）、
  鼠标上报、IME、选择与复制粘贴、Kitty 图形协议（PNG 已接入）。
- 终端尺寸随窗口/侧边栏变化自动同步给 PTY。
- 响应式布局：窗口宽度 ≥ 560 时显示常驻侧边栏，否则收进 AppBar 抽屉。
- 检查更新：启动时静默检查一次 GitHub Release，设置里可手动检查；下载用
  系统浏览器打开对应平台的安装包。

## 环境要求

- macOS 12 或更高（工程部署目标为 12.0）。
- Flutter 3.47 或更高（`ghostty_dart_flutter` 要求 `flutter >= 3.47.0`、
  `sdk ^3.13.5`；本机使用 mise 管理的 oh-3.47.7，CI 取同一 minor 的最新
  patch：官方 3.47.9 stable，Dart 3.13.7）。
- Xcode 命令行工具（构建 macOS 目标需要）。
- 首次 `flutter pub get` / 构建需要网络：`ghostty_dart` 的 build hook 会下载
  按 sha256 固定的预编译 libghostty-vt 动态库。

## 初始化与运行

```bash
# 1. 激活 mise（Flutter 版本）
eval "$(~/.local/bin/mise activate zsh)"

# 2. 首次克隆：连同子模块一起
git clone --recurse-submodules <repo-url> t
# 已克隆但 third/ghostty_dart 为空时：
git submodule update --init --recursive

# 3. 安装依赖
cd t
flutter pub get

# 4. 运行 macOS 应用
flutter run -d macos
```

其他常用命令：

```bash
flutter analyze          # 静态检查
flutter test             # 单元/Widget 测试
flutter build macos      # 生产构建
```

## 检查更新与发版

- 启动后静默检查一次 GitHub Release；设置对话框里的「检查更新」可手动检查。
- 本地版本取 `pubspec.yaml` 的 `version`（忽略 `+build` 后缀），与最新 Release
  的 tag（如 `v0.2.0`）逐段比较；有更新时弹窗，下载按钮用系统浏览器打开
  当前平台的安装包，没有匹配资产时打开 Release 页面。
- 发版：修改 `pubspec.yaml` 的 `version` → 提交 → 打 `vX.Y.Z` tag → 推送。
  [release.yml](.github/workflows/release.yml) 会构建 Android APK、Windows
  zip、macOS zip 并创建草稿 Release。Android 使用
  `--split-per-abi --target-platform android-arm64,android-x64`，只产出
  `arm64-v8a` 与 `x86_64` 两个安装包，应用按设备 ABI 选择下载。
- tag 必须与 pubspec 版本一致（CI 的 `prepare` job 会校验）；草稿 Release
  转为正式版后应用才能检查到：
  `gh release edit vX.Y.Z --draft=false --latest`。
- 仓库还没有 Release 或 GitHub API 限流（未认证 60 次/小时/IP）时，手动检查
  会提示失败，不影响应用使用。

## 依赖说明

| 依赖 | 来源 | 作用 |
|---|---|---|
| `flutter_pty_new` | pub.dev `^1.0.0` | 创建 PTY、跑本地 Shell |
| `ghostty_dart_flutter` | `third/ghostty_dart` 子模块 | 终端 widget（渲染、键盘、鼠标、IME） |
| `ghostty_dart` | 同上（`dependency_overrides` 锁定） | libghostty-vt 的 Dart 绑定 |
| `http` | pub.dev `^1.6.0` | 请求 GitHub Release API |
| `package_info_plus` | pub.dev `^10.2.2` | 读取应用版本号 |
| `device_info_plus` | pub.dev `^13.3.0` | 读取 Android ABI，选择对应 APK |
| `url_launcher` | pub.dev `^6.3.3` | 用系统浏览器打开下载链接 |

`ghostty_dart_flutter` 的 pubspec 把 `ghostty_dart` 声明为托管依赖，直接再加
path 依赖会与它冲突；因此根 `pubspec.yaml` 用 `dependency_overrides` 把
`ghostty_dart` 统一指向子模块里的同一份源码，避免两份不同版本的引擎。

## 平台配置说明

- **macOS 沙箱已关闭**（`macos/Runner/*.entitlements`）：开启 App Sandbox 时
  `forkpty` 出来的 Shell 会立刻退出（exit 255、无输出），终端不可用。
- **Android release 清单声明了 `INTERNET`**：检查更新需要访问 GitHub API。
  debug / profile 清单自带的 `INTERNET` 不会合并进 release，新增网络功能时
  要记得在 `android/app/src/main/AndroidManifest.xml` 声明。
- **Android 只打 64 位包**：构建使用
  `flutter build apk --release --split-per-abi --target-platform android-arm64,android-x64`，
  只产出 `arm64-v8a` 与 `x86_64`，Release 里没有 armeabi-v7a 安装包。
  不要在 Gradle 里再配 `ndk.abiFilters`，它与 `--split-per-abi` 互斥。
- **macOS 部署目标为 12.0**：`macos/Podfile` 的 `platform :osx, '12.0'` 与
  Xcode 工程一致；改这个值前先确认 Xcode 支持的最低版本。
- **macOS 启动时会把工作目录切到 app bundle 的 `Contents/Frameworks`**：
  `ghostty_dart` 的原生资产以相对路径 `ghostty-vt.framework/ghostty-vt` 交给
  `dlopen`，而 `flutter run` 的进程工作目录是工程根目录，不切换会报
  `Failed to load dynamic library`。flutter_pty_new 的动态库同样按相对路径
  打开，切过去后两者都能命中；Shell 的起始目录仍显式传 `$HOME`，不受影响。
- **flutter_pty_new 在 macOS 上按相对路径加载动态库**
  （`flutter_pty_new.framework/flutter_pty_new`）。`LocalPtySession` 在构造 PTY
  期间也会临时切到 `Contents/Frameworks` 再切回，作为双保险。
- **没有 Web 与 ohos 支持**：`ghostty_dart` 目前只有原生后端（wasm 计划中），
  平台声明不含 ohos；这两个目标构建会失败。
- **子模块有一处本地兼容改动**：鸿蒙版 Flutter SDK 的 `TargetPlatform` 多了
  `ohos`，`ghostty_dart_flutter` 里穷尽的 switch 无法编译，已把
  `terminal_shortcuts.dart` 的非 Apple 分支改成通配符。升级子模块后需要重新
  确认这处改动。

## 目录结构

```
lib/
├── main.dart                         # runApp + Kitty PNG 解码钩子
├── app.dart                          # MaterialApp + 主题 + 启动检查更新
├── app_menu.dart                     # macOS 菜单事件分发
├── app_breakpoints.dart              # 响应式断点
└── features/
    ├── about/widgets/about_dialog.dart
    ├── settings/                     # 偏好项、存储、设置对话框
    ├── update/                       # 版本比较、GitHub Release 请求、更新弹窗
    │   ├── models/update_info.dart
    │   ├── services/update_service.dart
    │   └── widgets/update_prompt.dart
    └── terminal/
        ├── models/terminal_tab.dart      # 标签（id / title / session）
        ├── providers/
        │   └── terminal_tabs_provider.dart  # 标签列表、激活项、会话生命周期
        ├── services/
        │   ├── terminal_session.dart     # ITerminalSession 接口
        │   ├── local_pty_session.dart    # PTY ↔ VtTerminalController 接线
        │   └── terminal_shell.dart       # 按平台推导 Shell 参数
        ├── screens/
        │   └── terminal_screen.dart      # 断点式侧边栏 / 抽屉布局
        └── widgets/
            ├── terminal_panel.dart       # VtTerminalView 封装 + 光标配置
            └── terminal_sidebar.dart     # 标签列表与新建/关闭
third/ghostty_dart/                   # git 子模块（终端引擎与 widget）
```

## 按键与粘贴

沿用 ghostty_dart_flutter 的桌面终端约定：

- 复制：`Ctrl+Shift+C` / `Ctrl+Insert`，macOS 上 `Cmd+C`。
- 粘贴：`Ctrl+Shift+V` / `Shift+Insert`，macOS 上 `Cmd+V`。
- `Ctrl+V`、`Ctrl+A` 会原样发给 Shell（字面量与行首），不被终端截获。
- 粘贴带换行且程序未开启 bracketed paste 时会被拦下（Ghostty 的粘贴保护）。

## 光标

- 默认使用更粗的竖向条光标（覆盖程序的 DECSCUSR 形状）。
- 光标跨单元格移动时以 smoothstep 缓动滑过去，默认 160 ms；移动发生在
  缓动中途时从当前绘制位置继续，不会跳回。
- 光标隐藏、滚出视口或处于闪烁的“灭”半周期时仍会缓动到位；高吞吐输出
  （flood）期间自动关闭缓动，保持刷帧节奏。
- 条状光标宽度可配置：上游默认是单元格宽度的 1/8，本应用默认 1/5。
- 在 [terminal_panel.dart](lib/features/terminal/widgets/terminal_panel.dart)
  的 `TerminalPanel` 上配置：

  ```dart
  TerminalPanel(
    session: session,
    cursorStyle: VtCursorStyle.bar,               // 或 null 跟随程序
    cursorGlide: true,
    cursorGlideDuration: const Duration(milliseconds: 160),
    barCursorThicknessFraction: 1 / 5,            // 上游默认 1/8
  )
  ```

## 字号缩放

- `Ctrl` + `0` 恢复默认字号（16），`Ctrl` + `-` 缩小一级，`Ctrl` + `=` 放大一级。
- `Ctrl` + 鼠标滚轮同样按 1 级缩放；按住 `Ctrl` 时滚轮只缩放，不滚动终端。
- 触控板双指捏合、触屏双指缩放按比例吸附到整数级。
- 范围 4–64，步进 1。字号变化立即生效，偏好文件延迟到停止调整 5 秒后写入；
  设置里的「终端字号」滑动条与快捷键共用同一份配置。

## 已知限制

- SSH 终端尚未实现。
- 不支持 Web（浏览器没有 PTY，ghostty 的 wasm 后端也未完成）与 ohos。
- 高吞吐输出（如 `yes`）未做额外限流，依赖引擎的滚动缓冲上限。
- 终端搜索、分屏、自定义配色不在当前范围。
