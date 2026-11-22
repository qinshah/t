import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// 与 Flutter 侧约定的菜单通道，事件由 `lib/app_menu.dart` 分发。
  private static let appMenuChannelName = "com.ivi.t/app_menu"

  private var appMenuChannel: FlutterMethodChannel?

  override func applicationWillFinishLaunching(_ notification: Notification) {
    super.applicationWillFinishLaunching(notification)

    // 终端需要“按住键连续输入”。macOS 默认会把长按字母变成变音符号候选菜单
    // （ApplePressAndHoldEnabled），而我们的按键由 Flutter 的文本输入客户端
    // 转成字符，于是长按只会弹候选框、不会重复。这里在窗口与文本输入建立之前
    // 关掉它：写进 App 自己的偏好域，优先级高于全局域，用户不必手动
    // `defaults write`。
    let defaults = UserDefaults.standard
    if defaults.object(forKey: "ApplePressAndHoldEnabled") as? Bool != false {
      defaults.set(false, forKey: "ApplePressAndHoldEnabled")
    }
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    // macOS 13 起系统把 “Preferences…” 更名为 “Settings…”。
    if #available(macOS 13.0, *),
       let appMenu = NSApp.mainMenu?.items.first?.submenu {
      appMenu.item(withTitle: "Preferences…")?.title = "Settings…"
    }
  }

  /// 把 macOS 菜单事件转发给 Flutter。
  private func sendAppMenu(_ method: String, arguments: Any? = nil) {
    guard let controller = NSApp.windows
      .compactMap({ $0.contentViewController as? FlutterViewController })
      .first else { return }

    let channel = appMenuChannel ?? FlutterMethodChannel(
      name: Self.appMenuChannelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    appMenuChannel = channel
    channel.invokeMethod(method, arguments: arguments)
  }

  /// 响应应用菜单里的 “Settings…”（⌘,）。
  ///
  /// 菜单项的目标是 First Responder，经响应链最终落到这里，再通过
  /// method channel 交给 Flutter 打开设置对话框。
  @objc func showSettingsWindow(_ sender: Any?) {
    sendAppMenu("openSettings")
  }

  /// 响应应用菜单里的 “About…”。
  ///
  /// 不能用系统的 `orderFrontStandardAboutPanel:`：它会新建原生窗口，
  /// 触发 Flutter 引擎 `enableMultiView` 的断言崩溃，所以改为在 Flutter
  /// 内展示“关于”对话框。
  @objc func showAppAbout(_ sender: Any?) {
    let info = Bundle.main.infoDictionary ?? [:]
    sendAppMenu("openAbout", arguments: [
      "name": info["CFBundleName"] as? String ?? "t",
      "version": info["CFBundleShortVersionString"] as? String ?? "",
      "copyright": info["NSHumanReadableCopyright"] as? String ?? "",
    ])
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
