import AppKit

@main
struct AlertPanelTests {
    static func main() {
        _ = NSApplication.shared
        let panel = AlertPanel(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                               styleMask: .borderless, backing: .buffered, defer: false)
        precondition(panel.canBecomeKey, "全屏提醒窗口必须可接收按钮操作")
        precondition(panel.canBecomeMain, "全屏提醒窗口必须能成为当前窗口")
        print("AlertPanelTests: 2 passed")
    }
}
