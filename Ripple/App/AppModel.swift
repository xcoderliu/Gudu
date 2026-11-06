import AppKit
import Combine
import RippleCore
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: ReminderSettings {
        didSet {
            saveSettings()
            if !settings.hasSameSchedule(as: oldValue) { reschedule() }
        }
    }
    @Published private(set) var entries: [HydrationEntry]
    @Published private(set) var now = Date()
    @Published private(set) var nextReminder: Date?
    @Published private(set) var isPresenting = false
    @Published private(set) var isScreenUnavailable = false
    @Published private(set) var displayCount = NSScreen.screens.count
    @Published private(set) var launchAtLogin = false
    @Published var serviceError: String?

    var onPresentReminder: ((_ preview: Bool) -> Void)?
    var onDismissReminder: (() -> Void)?

    private let defaults: UserDefaults
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var lastTick = Date()
    private var locked = false
    private var sleeping = false
    private var inactiveSession = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var restored = defaults.data(forKey: "reminderSettings")
            .flatMap { try? JSONDecoder().decode(ReminderSettings.self, from: $0) } ?? ReminderSettings()
        restored.normalize()
        settings = restored
        let cutoff = Date().addingTimeInterval(-90 * 24 * 60 * 60)
        entries = (defaults.data(forKey: "hydrationEntries")
            .flatMap { try? JSONDecoder().decode([HydrationEntry].self, from: $0) } ?? [])
            .filter { $0.date > cutoff }
        refreshLoginStatus()
        reschedule()
        observeSystem()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    var todayEntries: [HydrationEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: now) }
    }

    var todayML: Int { todayEntries.reduce(0) { $0 + $1.amountML } }
    var progress: Double { min(Double(todayML) / Double(settings.dailyGoalML), 1) }

    var countdown: String {
        guard let nextReminder else { return "已暂停" }
        let seconds = max(0, Int(ceil(nextReminder.timeIntervalSince(now))))
        if seconds >= 3600 {
            return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var statusText: String {
        if !settings.isEnabled { return "给自己一点自由，准备好再继续" }
        if isScreenUnavailable { return "休息中，解锁后继续陪伴" }
        if !settings.schedule.isActive(at: now) { return "安静时段，下一次从开始时间提醒" }
        return "下一次喝水，正在轻轻靠近"
    }

    func reschedule(delay: TimeInterval? = nil) {
        now = Date()
        nextReminder = settings.isEnabled && !isScreenUnavailable
            ? settings.schedule.nextReminder(after: now, delay: delay) : nil
    }

    func toggleEnabled() {
        settings.isEnabled.toggle()
        if !settings.isEnabled { onDismissReminder?() }
    }

    func recordDrink() {
        now = Date()
        entries.append(HydrationEntry(date: now, amountML: settings.servingML))
        let cutoff = now.addingTimeInterval(-90 * 24 * 60 * 60)
        entries.removeAll { $0.date < cutoff }
        saveEntries()
        reschedule()
    }

    func undoLastDrink() {
        guard let id = todayEntries.last?.id else { return }
        entries.removeAll { $0.id == id }
        saveEntries()
    }

    func preview() { present(preview: true) }

    func remindNow() { present(preview: false) }

    func finishReminder(_ action: ReminderAction, preview: Bool) {
        isPresenting = false
        guard !preview else { return }
        switch action {
        case .drank: recordDrink()
        case .snooze: reschedule(delay: 5 * 60)
        case .dismiss: reschedule()
        }
    }

    func refreshLoginStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLoginStatus()
            if enabled && SMAppService.mainApp.status == .requiresApproval {
                serviceError = "请在「系统设置 → 通用 → 登录项」中允许澄水在登录时打开。"
            }
        } catch {
            refreshLoginStatus()
            serviceError = "无法更新登录项：\(error.localizedDescription)\n请先将应用放到「应用程序」文件夹，再试一次。"
        }
    }

    private func present(preview: Bool) {
        guard !isPresenting, !isScreenUnavailable else { return }
        isPresenting = true
        onPresentReminder?(preview)
    }

    private func tick() {
        let instant = Date()
        let gap = instant.timeIntervalSince(lastTick)
        lastTick = instant
        now = instant
        // Long run-loop gaps (sleep, hibernation) never produce a burst of
        // overdue reminders. Start a fresh interval when the Mac is available.
        if gap > 90 || gap < -5 { reschedule(); return }
        guard settings.isEnabled, !isScreenUnavailable, !isPresenting,
              let due = nextReminder, due <= instant else { return }
        guard settings.schedule.isActive(at: instant), instant.timeIntervalSince(due) < 90 else {
            reschedule()
            return
        }
        reschedule()
        present(preview: false)
    }

    private func availabilityChanged() {
        let unavailable = locked || sleeping || inactiveSession
        guard isScreenUnavailable != unavailable else { return }
        isScreenUnavailable = unavailable
        if unavailable { onDismissReminder?() }
        lastTick = Date()
        reschedule()
    }

    private func observeSystem() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.displayCount = NSScreen.screens.count }
        })
        for name in [NSApplication.didBecomeActiveNotification, .NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refreshLoginStatus()
                    if name != NSApplication.didBecomeActiveNotification { self?.reschedule() }
                }
            })
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification,
                     NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    switch name {
                    case NSWorkspace.willSleepNotification: self.sleeping = true
                    case NSWorkspace.didWakeNotification: self.sleeping = false
                    case NSWorkspace.sessionDidResignActiveNotification: self.inactiveSession = true
                    case NSWorkspace.sessionDidBecomeActiveNotification: self.inactiveSession = false
                    default: break
                    }
                    self.availabilityChanged()
                }
            })
        }
        let distributed = DistributedNotificationCenter.default()
        for (name, isLocked) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            distributedObservers.append(distributed.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.locked = isLocked
                    self?.availabilityChanged()
                }
            })
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: "reminderSettings") }
    }

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: "hydrationEntries") }
    }
}

enum ReminderAction { case drank, snooze, dismiss }
