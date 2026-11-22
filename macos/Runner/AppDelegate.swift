import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
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

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
