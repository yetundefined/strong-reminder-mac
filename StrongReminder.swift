import AppKit
import ServiceManagement

final class StrongReminderApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store: AlarmStore
    private var alarms: [Alarm]
    private var pendingAlerts: [Alarm] = []
    private var currentAlert: Alarm?
    private var alertWindows: [NSPanel] = []
    private var soundTimer: Timer?
    private var checkTimer: Timer?
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var titleField: NSTextField!
    private var datePicker: NSDatePicker!
    private var listTextView: NSTextView!
    private var alarmPicker: NSPopUpButton!
    private var removeButton: NSButton!
    private var launchAtLoginButton: NSButton!
    private let loginSettings = LoginStartupSettings(service: MainAppLoginService())

    override init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("强提醒", isDirectory: true)
        store = AlarmStore(fileURL: support.appendingPathComponent("alarms.json"))
        alarms = (try? store.load()) ?? []
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        createStatusItem()
        createMainWindow()
        checkTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.checkAlarms() }
        RunLoop.main.add(checkTimer!, forMode: .common)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(checkAlarms), name: NSWorkspace.didWakeNotification, object: nil)
        checkAlarms()
        showMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshLoginStartupControl()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func createStatusItem() {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()
        let quitItem = NSMenuItem(title: "退出强提醒", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        applicationMenu.addItem(quitItem)
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "alarm.fill", accessibilityDescription: "强提醒")
        statusItem?.button?.toolTip = "强提醒"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开强提醒", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "预览全屏提醒", action: #selector(previewAlert), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "打开登录项设置", action: #selector(openLoginItemsSettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: ""))
        for item in menu.items { item.target = self }
        statusItem?.menu = menu
    }

    private func createMainWindow() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 575),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "强提醒"
        window.center()
        window.delegate = self
        window.minSize = NSSize(width: 510, height: 480)
        mainWindow = window

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = root

        let heading = label("添加提醒", size: 27, weight: .bold)
        let hint = label("到点覆盖整个屏幕，并持续响铃，直到你处理。", size: 13, weight: .regular)
        hint.textColor = .secondaryLabelColor
        let titleLabel = label("提醒内容", size: 14, weight: .semibold)
        titleField = NSTextField(string: "")
        titleField.placeholderString = "例如：现在去抢票！"
        titleField.font = .systemFont(ofSize: 16)
        let timeLabel = label("提醒时间", size: 14, weight: .semibold)
        datePicker = NSDatePicker()
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        datePicker.dateValue = AlarmPlanner.alignedToMinute(Date()).addingTimeInterval(660)
        datePicker.minDate = Date()
        datePicker.font = .systemFont(ofSize: 16)
        let addButton = NSButton(title: "添加提醒", target: self, action: #selector(addAlarm))
        addButton.bezelStyle = .rounded
        addButton.keyEquivalent = "\r"
        let previewButton = NSButton(title: "预览全屏效果", target: self, action: #selector(previewAlert))
        previewButton.bezelStyle = .rounded
        let buttonRow = NSStackView(views: [addButton, previewButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.alignment = .centerY
        launchAtLoginButton = NSButton(checkboxWithTitle: "登录时自动启动（推荐）",
                                      target: self, action: #selector(toggleLoginStartup))
        let upcoming = label("待提醒", size: 20, weight: .bold)
        listTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 504, height: 170))
        listTextView.isEditable = false
        listTextView.isSelectable = false
        listTextView.font = .systemFont(ofSize: 15)
        listTextView.textColor = .labelColor
        listTextView.drawsBackground = false
        listTextView.textContainerInset = NSSize(width: 4, height: 8)
        listTextView.isVerticallyResizable = true
        listTextView.isHorizontallyResizable = false
        listTextView.autoresizingMask = .width
        listTextView.textContainer?.widthTracksTextView = true
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = listTextView
        alarmPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        removeButton = NSButton(title: "删除选中提醒", target: self, action: #selector(removeAlarm))
        removeButton.bezelStyle = .rounded
        let removeRow = NSStackView(views: [alarmPicker, removeButton])
        removeRow.orientation = .horizontal
        removeRow.spacing = 10

        let stack = NSStackView(views: [heading, hint, titleLabel, titleField, timeLabel, datePicker,
                                        buttonRow, launchAtLoginButton, upcoming, scroll, removeRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -22),
            titleField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),
            alarmPicker.widthAnchor.constraint(equalToConstant: 270)
        ])
        refreshList()
        refreshLoginStartupControl()
    }

    private func refreshLoginStartupControl() {
        guard let launchAtLoginButton else { return }
        let status = loginSettings.status
        launchAtLoginButton.state = (status == .enabled || status == .requiresApproval) ? .on : .off
        launchAtLoginButton.title = status == .requiresApproval
            ? "登录时自动启动（请在系统设置中允许）"
            : "登录时自动启动（推荐）"
    }

    @objc private func toggleLoginStartup() {
        do {
            let status = try loginSettings.setEnabled(launchAtLoginButton.state == .on)
            refreshLoginStartupControl()
            if status == .requiresApproval {
                showMessage("请在“系统设置 → 通用 → 登录项与扩展”中允许强提醒。")
            }
        } catch {
            refreshLoginStartupControl()
            showMessage("无法更改登录时启动设置：\(error.localizedDescription)")
        }
    }

    @objc private func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    @objc private func showMainWindow() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func addAlarm() {
        let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { showMessage("请填写提醒内容"); return }
        let fireAt = AlarmPlanner.alignedToMinute(datePicker.dateValue)
        guard fireAt > Date().addingTimeInterval(3) else { showMessage("请选择将来的时间"); return }
        alarms.append(Alarm(id: UUID(), title: title, fireAt: fireAt))
        alarms.sort { $0.fireAt < $1.fireAt }
        persist()
        titleField.stringValue = ""
        datePicker.dateValue = AlarmPlanner.alignedToMinute(Date()).addingTimeInterval(660)
        refreshList()
    }

    private func refreshList() {
        listTextView.string = AlarmListFormatter.lines(alarms)
        alarmPicker.removeAllItems()
        for alarm in alarms {
            alarmPicker.addItem(withTitle: alarm.title)
            alarmPicker.lastItem?.representedObject = alarm.id.uuidString
        }
        alarmPicker.isEnabled = !alarms.isEmpty
        removeButton.isEnabled = !alarms.isEmpty
    }

    @objc private func removeAlarm() {
        guard let raw = alarmPicker.selectedItem?.representedObject as? String,
              let id = UUID(uuidString: raw) else { return }
        alarms.removeAll { $0.id == id }
        persist()
        refreshList()
    }

    private func persist() {
        do { try store.save(alarms) }
        catch { showMessage("保存提醒失败：\(error.localizedDescription)") }
    }

    private func showMessage(_ text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.addButton(withTitle: "知道了")
        if let mainWindow { alert.beginSheetModal(for: mainWindow) }
        else { alert.runModal() }
    }

    @objc private func checkAlarms() {
        let due = AlarmPlanner.consumeDue(from: &alarms, at: Date(), maxLateness: 3_600)
        guard !due.isEmpty else { return }
        persist()
        refreshList()
        pendingAlerts.append(contentsOf: due)
        showNextAlert()
    }

    @objc private func previewAlert() {
        pendingAlerts.append(Alarm(id: UUID(), title: "这是全屏提醒预览", fireAt: Date()))
        showNextAlert()
    }

    private func showNextAlert() {
        guard currentAlert == nil, !pendingAlerts.isEmpty else { return }
        currentAlert = pendingAlerts.removeFirst()
        guard let alarm = currentAlert else { return }
        for screen in NSScreen.screens {
            let panel = AlertPanel(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            panel.title = "强提醒 - 全屏提示"
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.backgroundColor = NSColor(calibratedRed: 0.53, green: 0.04, blue: 0.09, alpha: 1)
            panel.isOpaque = true
            panel.hasShadow = false
            panel.contentView = alertContent(for: alarm, frame: screen.frame)
            alertWindows.append(panel)
            panel.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        NSSound.beep()
        soundTimer = Timer(timeInterval: 2, repeats: true) { _ in NSSound.beep() }
        RunLoop.main.add(soundTimer!, forMode: .common)
    }

    private func alertContent(for alarm: Alarm, frame: NSRect) -> NSView {
        let root = NSView(frame: NSRect(origin: .zero, size: frame.size))
        let eyebrow = label("强提醒 · 现在", size: 20, weight: .semibold)
        eyebrow.textColor = NSColor.white.withAlphaComponent(0.82)
        let title = label(alarm.title, size: 64, weight: .heavy)
        title.textColor = .white
        title.alignment = .center
        title.maximumNumberOfLines = 3
        title.lineBreakMode = .byWordWrapping
        let dismiss = NSButton(title: "我知道了", target: self, action: #selector(dismissAlert))
        dismiss.font = .systemFont(ofSize: 22, weight: .bold)
        dismiss.isBordered = false
        dismiss.wantsLayer = true
        dismiss.layer?.backgroundColor = NSColor.white.cgColor
        dismiss.layer?.cornerRadius = 12
        dismiss.attributedTitle = NSAttributedString(string: "我知道了", attributes: [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.40, green: 0.03, blue: 0.08, alpha: 1)
        ])
        let snooze = NSButton(title: "5 分钟后再提醒", target: self, action: #selector(snoozeAlert))
        snooze.font = .systemFont(ofSize: 18)
        snooze.isBordered = false
        snooze.wantsLayer = true
        snooze.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.22).cgColor
        snooze.layer?.cornerRadius = 12
        snooze.attributedTitle = NSAttributedString(string: "5 分钟后再提醒", attributes: [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.white
        ])
        let buttons = NSStackView(views: [dismiss, snooze])
        buttons.orientation = .horizontal
        buttons.spacing = 18
        let stack = NSStackView(views: [eyebrow, title, buttons])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 32
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: root.widthAnchor, multiplier: 0.82),
            title.widthAnchor.constraint(lessThanOrEqualTo: root.widthAnchor, multiplier: 0.82),
            dismiss.widthAnchor.constraint(equalToConstant: 170),
            dismiss.heightAnchor.constraint(equalToConstant: 55),
            snooze.widthAnchor.constraint(equalToConstant: 210),
            snooze.heightAnchor.constraint(equalToConstant: 55)
        ])
        return root
    }

    @objc private func dismissAlert() { closeAlert() }

    @objc private func snoozeAlert() {
        if let currentAlert {
            alarms.append(AlarmPlanner.snooze(currentAlert, from: Date(), minutes: 5))
            alarms.sort { $0.fireAt < $1.fireAt }
            persist()
            refreshList()
        }
        closeAlert()
    }

    private func closeAlert() {
        soundTimer?.invalidate()
        soundTimer = nil
        for window in alertWindows { window.orderOut(nil) }
        alertWindows.removeAll()
        currentAlert = nil
        showNextAlert()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

@main
struct StrongReminderMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = StrongReminderApp()
        app.delegate = delegate
        app.run()
    }
}
