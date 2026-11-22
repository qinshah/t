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
CI 的 Flutter 版本固定在 `.github/workflows/release.yml`，优先与本地
`mise` 版本对齐（本地 `oh-3.47.7` → CI `3.47.7`），并满足
`pubspec.yaml` 的 `environment.sdk`（当前 `^3.13.5`）。

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

4. **光标动画回归：**
   - 测试属于子模块：`packages/ghostty_dart_flutter/test/render/
     terminal_render_test.dart`，覆盖 smoothstep 缓动、中途改目标、
     隐藏光标与关闭缓动
   - 可在 t 仓直接跑（使用 t 的包解析）：
     `flutter test third/ghostty_dart/packages/ghostty_dart_flutter/test/render/terminal_render_test.dart --plain-name cursor`

## 项目依赖与约定

- **状态管理：** 标签状态用原生 `ChangeNotifier` + `ListenableBuilder`；
  应用级偏好用 `provider` 的 `ChangeNotifierProvider<SettingsProvider>` 管理
- **UI：** Material 3（`useMaterial3: true`），不使用 Hux
- **终端引擎：** `third/ghostty_dart` 子模块（`ghostty_dart` + `ghostty_dart_flutter`）
- **PTY：** pub.dev 上的 `flutter_pty_new ^1.0.0`
- **其他依赖：** `panes ^1.6.0`（宽屏可拖侧边栏）、`path_provider ^2.1.6`
  （偏好文件位置）、`provider ^6.1.5`（偏好状态）、`http ^1.6.0`（GitHub
  Release API）、`package_info_plus ^10.2.2`（读应用版本）、
  `url_launcher ^6.3.3`（系统浏览器打开下载链接）
- **范围：** 应用只提供终端功能，不内置 MCP 服务、driver 入口或调试脚本

### 响应式布局

- 断点集中在 `lib/app_breakpoints.dart`：`wideLayoutBreakpoint = 560`
  （常见手机逻辑宽度约 390–412 的 1.4 倍）。
- 尺寸在 `lib/features/terminal/screens/terminal_screen.dart`：
  侧边栏初始 264，可拖动范围 200–420。
- 宽屏：`MultiPane`（`panes` 包）常驻侧边栏 + 内容区，分隔条可拖动；
  窄屏：AppBar 抽屉 + 内容区。
- 侧边栏宽屏常驻与窄屏抽屉直接复用同一个 `TerminalSidebar`，不区分变体；
  侧边栏内部通过是否位于 `Drawer` 中决定操作后是否收起抽屉。
- 右上角操作：侧边栏头部（两种布局都有）与窄屏 AppBar `actions` 都提供
  「新建终端 → 设置」，顺序一致。
- 设置对话框按同一断点决定形态：两种形态都是普通 `Dialog` 覆盖层，
  不使用 `Dialog.fullscreen`（会触发系统级全屏）。宽屏保留默认
  `insetPadding` 并限制内容最大 520×560；窄屏 `insetPadding: EdgeInsets.zero`
  铺满窗口。对话框打开期间跨过断点要实时切换。
- 两种布局共享同一个 `TerminalTabsProvider`，改变窗口宽度不会重建会话。
- 所有标签的 `TerminalPanel` 必须留在 widget 树中（`IndexedStack`），
  否则切换标签会丢会话状态。

### 偏好设置

- 偏好文件：`getApplicationSupportDirectory()/preferences.json`，由
  `SettingsStore`（`lib/features/settings/services/settings_store.dart`）
  读入内存 Map 后异步落盘；读写失败一律回退默认值，不得影响启动。
- 偏好项用 `Setting<Value, Data>` 静态实例声明
  （`lib/features/settings/models/setting.dart`，参考 flutter_bili 的
  `settings_s.dart`）：`get()` 同步读当前值，`set()` 在值等于默认值时
  直接删除存储项，`isDefault` 供设置页判断是否显示「恢复默认」。
- 持久化 JSON 只存基本类型（`String` / `bool` / `num`），key 是
  `SettingEnum.name`；复杂值用 `enCoder` / `deCoder` 转换，不要存序列化
  对象或颜色值。当前只有 `themeMode`、`terminalThemeMode`、
  `quitWhenLastClosed` 三项。
- 新增配置项必须：
  1. 在 `SettingEnum` 增加名称与标题；
  2. 增加 `Setting` 静态实例并给 `defValue`；
  3. 在 `SettingsProvider` 暴露 getter / setter / reset / `isXxxDefault`；
  4. 在设置对话框用 `_PreferenceTile` 展示。
- 设置项布局：标题行是「标题 + 恢复按钮 + 控件」，下一行是简介。
  两个深浅项用 `CupertinoSlidingSegmentedControl`，选项直接复用 SDK
  `ThemeMode`，标签统一翻译为「自动 / 暗色 / 亮色」；开关项用 `Switch`。
- 终端配色没有偏好项：色板硬编码在
  `lib/features/settings/models/solarized_themes.dart`，只按
  `terminalThemeMode` 与 `Theme.of(context).brightness` 取明/暗两套。
  切换时通过 `ITerminalSession.applyTheme` → `VtTerminalController.theme`
  热更新，不重建会话。
- 「自动退出」默认开启；关闭最后一个标签会调用
  `TerminalTabsProvider.onLastTabClosed` 并退出应用。
- 界面深浅映射到 `MaterialApp.themeMode`；浅色与深色两套 `ThemeData`
  都要维护，不要在页面里硬编码背景色。

### TERM 与颜色

- `resolveShellSpec` 在父进程环境缺少非空 `TERM` 时注入
  `xterm-256color`；已有值不覆盖。`flutter_pty_new` 内部也会兜底，
  但应用层显式注入便于测试与替换 PTY 后端。

### 会话与标签的生命周期

- 会话按标签的稳定 `id`（`terminal-N`）索引，不依赖列表下标。
- 新建标签先 `await` 会话创建、再插入列表，避免出现不可用的标签。
- 关闭标签后等下一帧再 `dispose` 会话，否则 `VtTerminalView` 卸载时会用到
  已释放的 `FocusNode` / 控制器。
- 退出应用时立即终止所有 Shell，避免留下孤儿进程。

### 检查更新与发版

- 更新检查在 `lib/features/update/`：`UpdateService` 请求
  `api.github.com/repos/qinshah/t/releases/latest`，`compareVersions` 按
  语义化版本比较（忽略 `v` 前缀与 `+build`）。
- 启动检查在 `TerminalApp.initState` 的首帧回调；设置里的「检查更新」是手动
  入口。对话框必须用 `DialogRoute`，不能用 `showDialog`（macOS 会崩）。
- 下载按平台匹配 Release 资产命名（`t-vX.Y.Z-android.apk` /
  `-windows.zip` / `-macos.zip`），用系统浏览器打开；没有匹配资产时打开
  Release 页面。
- 发版由 `.github/workflows/release.yml` 驱动：推送 `vX.Y.Z` tag 触发构建。
  tag 必须与 `pubspec.yaml` 的 `version` 一致（CI 会校验），草稿 Release
  发布后应用才能检查到。
- 相关技能：`.agents/skills/release/SKILL.md`（发版流程）、
  `.agents/skills/update-check/SKILL.md`（更新检查实现约束）。

### 第三方依赖管理

`third/ghostty_dart` 是 **git 子模块**，不是普通目录：

- **不要修改子模块内容**。需要改引擎行为时先向上游提 issue/PR，或临时在本地
  实验后丢弃；提交前用 `git status` 确认子模块没有未提交改动。
- **已知的本地改动（两处）**：
  1. 鸿蒙版 Flutter SDK 的 `TargetPlatform` 多出 `TargetPlatform.ohos`，
     `packages/ghostty_dart_flutter/lib/src/input/keyboard/
     terminal_shortcuts.dart` 里穷尽的 switch 无法编译。已把非 Apple 分支改成
     通配符 `_`（归入 Linux/Windows 快捷键约定）。
  2. 光标动画与样式：`packages/ghostty_dart_flutter/lib/src/render/
     terminal_render.dart` 与 `lib/src/view/terminal_view.dart` 增加
     `cursorGlide` / `cursorGlideDuration`（默认 160ms、smoothstep vsync
     Ticker）和 `barCursorThicknessFraction`（上游默认保持 1/8，t 应用传
     1/5，避免改动上游 `cursor_bar.png` golden）。对应测试在
     `test/render/terminal_render_test.dart`（含 `render_harness.dart`
     的参数透传）。应用侧在 `TerminalPanel` 默认使用条状光标与 160ms。
  升级子模块后如果这些改动被覆盖，需要重新打上，否则会分别导致
  macOS 构建失败、光标动画与样式丢失。
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

- 光标默认是加粗的竖向条（`TerminalPanel.cursorStyle` 与
  `barCursorThicknessFraction`），跨单元格移动由 `VtTerminalView` 的
  `cursorGlide` / `cursorGlideDuration` 控制；改样式、粗细或时长只动
  `TerminalPanel`，不要在页面里直接建 `VtTerminalView`。
- 上游默认条状光标粗细是 1/8；不要在子模块里直接改默认值，否则会让
  `cursor_bar.png` golden 失效。加粗只通过 `barCursorThicknessFraction`
  在应用侧覆盖。
- 光标缓动由渲染盒内的 vsync `Ticker` 驱动，flood 输出期间会自动关闭；不要
  在应用层再叠加一套光标动画。
- 输入输出一律走 `VtTerminalController`：输出用 `writeBytes`，输入转发
  `onOutput`；不要直接调用 `controller.terminal.write`。
- `onResize(cols, rows, ...)` 与 `Pty.resize(rows, cols)` 参数顺序相反，
  转换只发生在 `LocalPtySession` 内。
- 不要在 `build` 里改 `controller.theme`；主题只在会话创建时设置。
- 复制粘贴快捷键遵循 ghostty 约定（`Ctrl+V` / `Ctrl+A` 属于 Shell），
  不要用 `Shortcuts` 抢占这些组合。

## 提交前规范（AI 开发）

每次准备提交、打 tag 或发版前，按顺序完成下面的检查；不通过就不要提交。

### 1. 代码验证

- `flutter analyze` 无 issue。
- `flutter test` 全部通过；只改文档时也至少跑一次 `flutter analyze`。
- 改动 PTY、原生库加载、主题热更新等行为时，额外在 `flutter run -d macos`
  下实际验证启动、输入输出与退出。

### 2. 文档与现状一致

- `AGENTS.md`、`README.md` 必须与代码一致：依赖、目录、入口、构建/发版方式、
  平台限制、断点等改了就要同步（例如新增依赖必须更新 README 的依赖表）。
- 有 `CHANGELOG.md` 时补对应版本条目；发版说明（tag 信息、Release notes）
  与应用版本一致，写用户能看懂的变更，不照抄 commit。
- 检查引用的文件路径、命令、环境变量是否仍然存在且可执行。

### 3. 脱敏检查

提交内容不得包含：

- token、密码、私钥、证书、签名文件、`.env` 内容；
- 个人绝对路径（如 `/Users/<name>`）、内网地址、未公开仓库或服务地址；
- 真实设备序列号、账号、手机号等个人信息。

示例值一律用占位符（`<repo-url>`、`/path/to/...`）。

### 4. 面向未知开发环境

其他开发者/CI 的环境是未知的，文档与脚本不能假设：

- 不假设 Flutter、Dart、Xcode、系统版本或安装路径；用 mise 或文档中写明的
  方式激活环境，版本要求写进 README / workflow。
- 路径用相对路径、`$HOME` 或命令推导，不写死本机目录。
- 依赖网络时说明镜像、代理与失败表现（如 `ghostty_dart` 的预编译下载、
  GitHub API 限流）。
- 构建与发版步骤要能在本地和 CI 复现，不依赖某台机器上的全局配置。

### 5. 提交与版本

- 按模块拆分提交，信息用 `feat/fix/chore/docs/test/ci` 前缀，说明"做了什么、
  为什么"。
- 发版必须同时修改 `pubspec.yaml` 的 `version`（构建号 `+N` 递增）并打
  `vX.Y.Z` tag；CI 会校验两者一致。
