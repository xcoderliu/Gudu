import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var model: AppModel!
    private var overlay: ReminderWindowController!
    private var mainWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        overlay = ReminderWindowController(model: model)
        model.onPresentReminder = { [weak self] preview in self?.overlay.present(preview: preview) }
        model.onDismissReminder = { [weak self] in self?.overlay.dismiss(action: .dismiss) }
        buildStatusItem()
        model.$now.sink { [weak self] _ in self?.updateStatusTooltip() }.store(in: &subscriptions)
        model.$settings.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateStatusTooltip() }
        }.store(in: &subscriptions)

        // A login-item launch stays in the menu bar; a normal launch shows the
        // dashboard. Closing the dashboard never stops the reminder scheduler.
        let isLogin = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !isLogin { showMainWindow() }
        if ProcessInfo.processInfo.arguments.contains("--preview") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.model.preview() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    @objc func showMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1060, height: 760),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.title = "澄水 · Ripple"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(Palette.background)
            window.minSize = NSSize(width: 960, height: 710)
            window.contentView = NSHostingView(rootView: DashboardView(model: model))
            window.setFrameAutosaveName("RippleDashboard")
            window.delegate = self
            window.center()
            mainWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Keep a discoverable menu-bar item while the main window is closed.
        DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "澄水喝水提醒")
        image?.isTemplate = true
        item.button?.image = image
        item.menu = NSMenu()
        item.menu?.delegate = self
        statusItem = item
        updateStatusMenu()
    }

    private func updateStatusTooltip() {
        guard let model else { return }
        statusItem?.button?.toolTip = "澄水 · \(model.settings.isEnabled ? "下次提醒 \(model.countdown)" : "已暂停")"
    }

    func menuWillOpen(_ menu: NSMenu) { updateStatusMenu() }

    private func updateStatusMenu() {
        guard let menu = statusItem?.menu, let model else { return }
        updateStatusTooltip()
        menu.removeAllItems()
        let title = NSMenuItem(title: "澄水 · 给忙碌留一口水", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        let state = NSMenuItem(title: "今日 \(model.todayML) / \(model.settings.dailyGoalML) mL  ·  \(model.countdown)", action: nil, keyEquivalent: "")
        state.isEnabled = false
        menu.addItem(state)
        menu.addItem(.separator())
        addItem("打开澄水", action: #selector(showMainWindow), key: "o", to: menu)
        addItem("喝一杯 +\(model.settings.servingML) mL", action: #selector(recordDrink), key: "d", to: menu)
        addItem("现在提醒我", action: #selector(remindNow), key: "r", to: menu)
        addItem("预览全屏动画", action: #selector(preview), key: "p", to: menu)
        menu.addItem(.separator())
        addItem(model.settings.isEnabled ? "暂停提醒" : "继续提醒", action: #selector(toggleEnabled), key: "", to: menu)
        menu.addItem(.separator())
        addItem("退出澄水", action: #selector(quit), key: "q", to: menu)
    }

    private func addItem(_ title: String, action: Selector, key: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func recordDrink() { model.recordDrink() }
    @objc private func remindNow() { model.remindNow() }
    @objc private func preview() { model.preview() }
    @objc private func toggleEnabled() { model.toggleEnabled() }
    @objc private func quit() { NSApp.terminate(nil) }
}
