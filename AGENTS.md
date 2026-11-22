# 开发指南

## 开发调试工具

终端应用本身只提供终端功能，**不内置 MCP 服务、driver 调试入口或预制脚本**；
下面的 MCP 服务器仅用于开发阶段。

### 1. dart-mcp-server

| 工具 | 用途 |
|------|------|
| `dtd` | 连接 Dart Tooling Daemon（`listDtdUris` 可能为空，直接用 `flutter run --print-dtd` 打印的 URI `connect`） |
| `hot_reload` | 热重载（保留状态应用代码改动） |
| `hot_restart` | 热重启（重置状态，含全局 const 更新） |
| `get_runtime_errors` | 获取运行时报错（可顺便清空旧错误） |
| `analyze_files` | 静态分析（类似 `dart analyze`） |
| `lsp` | Dart LSP 操作（定义跳转、重命名等） |
| `widget_inspector` | 查看 Widget 树 / 选中组件 |
| `pub` | pub 命令：add/get/remove/upgrade/deps/outdated |
| `pub_dev_search` | 搜索 pub.dev 包 |
| `rip_grep_packages` | 在包源码里全局搜索 |
| `read_package_uris` | 读取包的文件 URI |
| `roots` | 查询工作区根目录 |

本项目没有 `driver_main.dart`，因此 `flutter_driver_command` 不可用；需要看
布局时用 `widget_inspector` 的 `get_widget_tree`。

### 2. flutter-ai-whisper

| 工具 | 用途 |
|------|------|
| `discover_running_apps` | 发现正在运行的 Flutter app |
| `connect_to_app` | 连接到 app（可用启动日志里的 `ws://127.0.0.1:<port>/ws`） |
| `list_active_state_holders` | 列出运行中的状态（Provider/Bloc/Cubit 等） |
| `inject_state_variable` | 运行时注入/修改状态 |
| `trigger_route_navigation` | 触发路由导航 |

## 开发环境配置

### 版本管理工具

项目使用 **mise** 管理开发工具版本：

- **Flutter**: oh-3.47.7（鸿蒙版 Flutter SDK，Dart 3.13.5）
- **Dart**: 随 Flutter 安装

`ghostty_dart_flutter` 要求 `flutter >= 3.47.0`，低于该版本的 SDK 无法解析依赖。

### 环境激活

如果 `flutter` 命令找不到或版本不正确（例如报 `flutter: command not found`），
在**每条新 shell**里先激活 mise，再执行 Flutter 命令：

```bash
# 激活 mise
eval "$(~/.local/bin/mise activate zsh)"

# 验证环境
mise current
flutter --version
```

非交互式脚本里可以只对单条命令加 PATH：

```bash
export PATH="$HOME/.local/bin:$PATH"
flutter analyze
```

### 初始化项目依赖

```bash
# 子模块（终端引擎）
git submodule update --init --recursive

# 安装依赖（首次会触发 ghostty_dart 下载预编译 libghostty-vt）
flutter pub get

# 检查依赖状态
flutter pub outdated
```

### macOS 桌面构建注意事项

- **不要重新打开 App Sandbox**：`macos/Runner/DebugProfile.entitlements` 与
  `Release.entitlements` 里的 `com.apple.security.app-sandbox` 已被移除。开启时
  PTY 能创建、但 fork 出的 Shell 会立即退出（exit 255、无输出），终端不可用。
- **部署目标是 12.0**：Xcode 26+ 不再支持 10.15。`macos/Podfile` 的
  `platform :osx, '12.0'` 与 Xcode 工程保持一致；改这个值前先确认 Xcode
  支持的最低版本。
- **不要调用 `Pty.hasTty`**：`flutter_pty_new` 的 macOS 原生库里没有
  `pty_has_tty` 符号，调用会抛 `Failed to lookup symbol`。本工程只用
  `Pty.start` / `output` / `write` / `resize` / `kill` / `exitCode`。
- **flutter_pty_new 按相对路径 dlopen**：macOS 上会打开
  `flutter_pty_new.framework/flutter_pty_new`，依赖进程工作目录。`main()` 在
  启动时会把 `Directory.current` 切到 app bundle 的 `Contents/Frameworks`，
  `LocalPtySession` 构造 PTY 时也会再切一次作为双保险，并在启动参数里显式传
  起始目录。改动这段逻辑前先在 `flutter run -d macos` 下验证。
- **libghostty-vt 也按相对路径加载**：原生资产清单里写的是
  `ghostty-vt.framework/ghostty-vt`，同样是相对工作目录的路径。不切到
  `Contents/Frameworks` 会报 `Failed to load dynamic library`，表现为启动即
  崩溃、终端区域空白。`lib/main.dart` 的 `_enterMacosFrameworkDirectory` 就是
  为此存在，不要在 `runApp` 之前跳过它。
- **libghostty-vt 来自 build hook**：`ghostty_dart` 默认下载 sha256 固定的预编译
  二进制，校验失败会直接报错。离线或自定义构建可在根 `pubspec.yaml` 配置
  `hooks: user_defines: ghostty_dart:`（见子模块 `packages/ghostty_dart/README.md`）。

---

## 开发工作流

### 创建新项目

**必须使用命令行工具创建项目，不允许手动搭建文件结构：**

```bash
# 创建新的 Flutter 项目
flutter create [project_name]

# 创建新的 Dart 包
dart pub create -t package [package_name]
```

这样可以确保项目遵循 Flutter/Dart 官方规范和最佳实践。

### 本地开发

1. **安装依赖：**
   ```bash
   flutter pub get
   ```

2. **运行应用：**
   ```bash
   flutter run -d macos
   ```

3. **构建应用：**
   ```bash
   flutter build apk    # Android
   flutter build ios    # iOS
   ```

### 调试

1. **使用 Hot Reload：**
   - `flutter run -d macos` 后按 `r` 热重载、`R` 热重启
   - 想在编辑器外使用 MCP：`flutter run --print-dtd -d macos`，把日志里的
     `The Dart Tooling Daemon is available at: ws://...` 交给 dart-mcp-server
     的 `dtd` 工具 `connect`，之后可用 `hot_reload` / `get_runtime_errors` /
     `widget_inspector`
   - **PTY / Shell 相关的原生状态不会随热重载重置**；改会话生命周期或
     `third/` 下的代码后应热重启或重新 `flutter run`
   - 热重载后标签与各标签的 PTY 会话保持存活

2. **排查渲染问题：**
   - 终端画面由 `VtTerminalView` 自绘，Widget 树里看不到单元格内容
   - 字体、颜色、尺寸问题优先检查 `TerminalPanel` 传入的 `textStyle`
     和 `controller.theme`
   - 启动失败优先看 `flutter run` 的日志：原生库加载、PTY spawn 失败都会
     打印 `LocalPtySession:` 前缀的错误

3. **状态检查：**
   - 标签状态由 `TerminalTabsProvider`（`ChangeNotifier`）持有
   - 需要临时观察时可在 provider 的回调里加 `debugPrint`，排查完删除

## 项目依赖与约定

- **状态管理：** 原生 `ChangeNotifier` + `ListenableBuilder`，不引入 provider
- **UI：** Material 3（`useMaterial3: true`），不使用 Hux
- **终端引擎：** `third/ghostty_dart` 子模块（`ghostty_dart` + `ghostty_dart_flutter`）
- **PTY：** pub.dev 上的 `flutter_pty_new ^1.0.0`
- **范围：** 应用只提供终端功能，不内置 MCP 服务、driver 入口或调试脚本

### 响应式布局

- 断点与尺寸集中在 `lib/features/terminal/screens/terminal_screen.dart`：
  `_sidebarBreakpoint = 900`、`_sidebarWidth = 264`。
- 宽屏：常驻侧边栏 + 内容区；窄屏：AppBar 抽屉 + 内容区。
- 两种布局共享同一个 `TerminalTabsProvider`，改变窗口宽度不会重建会话。
- 所有标签的 `TerminalPanel` 必须留在 widget 树中（`IndexedStack`），
  否则切换标签会丢会话状态。

### 会话与标签的生命周期

- 会话按标签的稳定 `id`（`terminal-N`）索引，不依赖列表下标。
- 新建标签先 `await` 会话创建、再插入列表，避免出现不可用的标签。
- 关闭标签后等下一帧再 `dispose` 会话，否则 `VtTerminalView` 卸载时会用到
  已释放的 `FocusNode` / 控制器。
- 退出应用时立即终止所有 Shell，避免留下孤儿进程。

### 第三方依赖管理

`third/ghostty_dart` 是 **git 子模块**，不是普通目录：

- **不要修改子模块内容**。需要改引擎行为时先向上游提 issue/PR，或临时在本地
  实验后丢弃；提交前用 `git status` 确认子模块没有未提交改动。
- **已知的本地兼容补丁（唯一一处）**：鸿蒙版 Flutter SDK 的 `TargetPlatform`
  多出 `TargetPlatform.ohos`，`packages/ghostty_dart_flutter/lib/src/input/
  keyboard/terminal_shortcuts.dart` 里穷尽的 switch 无法编译。已把非 Apple
  分支改成通配符 `_`（归入 Linux/Windows 快捷键约定）。升级子模块后如果这处
  改动被覆盖，需要重新打上，否则 `flutter build macos` 会失败。
- 不要在子模块里执行 `git checkout` / `git restore` 覆盖上游代码。
- 升级：`git submodule update --remote third/ghostty_dart`，然后
  `flutter pub get` 并重新验证（上游 API 可能变化）。
- 依赖写法：

  ```yaml
  dependencies:
    ghostty_dart: any
    ghostty_dart_flutter:
      path: third/ghostty_dart/packages/ghostty_dart_flutter

  dependency_overrides:
    ghostty_dart:
      path: third/ghostty_dart/packages/ghostty_dart
  ```

  不能同时给 `ghostty_dart` 写 path 依赖：`ghostty_dart_flutter` 自己声明的
  托管约束会与它冲突，必须用 override 统一。
- `analysis_options.yaml` 已排除 `third/**`：子模块的 `tool/`、`benchmarks/`
  等目录不属于本工程，加入分析会引入大量无关报错。

### 终端相关的行为约定

- 输入输出一律走 `VtTerminalController`：输出用 `writeBytes`，输入转发
  `onOutput`；不要直接调用 `controller.terminal.write`。
- `onResize(cols, rows, ...)` 与 `Pty.resize(rows, cols)` 参数顺序相反，
  转换只发生在 `LocalPtySession` 内。
- 不要在 `build` 里改 `controller.theme`；主题只在会话创建时设置。
- 复制粘贴快捷键遵循 ghostty 约定（`Ctrl+V` / `Ctrl+A` 属于 Shell），
  不要用 `Shortcuts` 抢占这些组合。
