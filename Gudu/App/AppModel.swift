import AppKit
import Combine
import GuduCore
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: ReminderSettings {
        didSet {
            saveSettings()
            if !settings.hasSameSchedule(as: oldValue) { reschedule() }
            else if settings.preparationLeadMinutes != oldValue.preparationLeadMinutes || settings.displayMode != oldValue.displayMode {
                refreshPreparation()
            }
            if oldValue.requireDrinkVerification && !settings.requireDrinkVerification { onVerificationDisabled?() }
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
    var onTestVerification: (() -> Void)?
    var onVerificationDisabled: (() -> Void)?
    var onPresentPreparation: ((_ minutes: Int) -> Void)?
    var onDismissPreparation: (() -> Void)?

    private let defaults: UserDefaults
    private let clock: () -> Date
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var lastTick = Date()
    private var locked = false
    private var sleeping = false
    private var inactiveSession = false
    private var regularReminder: Date?
    private var catchUpReminder: Date?
    private var interruptedReminder = false
    private var interruptionDismissal = false
    private var presentingPreview = false
    private var preparationPlan: PreparationReminderPlan?
    private var lastPreparedReminder: Date?
    private var allowsPreparation = true

    init(defaults: UserDefaults = .standard, clock: @escaping () -> Date = Date.init, startsTimer: Bool = true) {
        self.defaults = defaults
        self.clock = clock
        var restored = defaults.data(forKey: "reminderSettings")
            .flatMap { try? JSONDecoder().decode(ReminderSettings.self, from: $0) } ?? ReminderSettings()
        restored.normalize()
        settings = restored
        let cutoff = clock().addingTimeInterval(-90 * 24 * 60 * 60)
        entries = (defaults.data(forKey: "hydrationEntries")
            .flatMap { try? JSONDecoder().decode([HydrationEntry].self, from: $0) } ?? [])
            .filter { $0.date > cutoff }
        refreshLoginStatus()
        reschedule()
        lastTick = clock()
        observeSystem()
        guard startsTimer else { return }
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
        guard let nextReminder else { return settings.isEnabled && settings.weekdays.isEmpty ? "未选提醒日" : "已暂停" }
        let seconds = max(0, Int(ceil(nextReminder.timeIntervalSince(now))))
        if seconds >= 3600 {
            return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var statusText: String {
        if !settings.isEnabled { return "给自己一点自由，准备好再继续" }
        if isScreenUnavailable { return "休息中，解锁后继续陪伴" }
        if settings.weekdays.isEmpty { return "未选择提醒日期，自动提醒已暂停" }
        if !settings.schedule.isActive(at: now) { return "安静时段，等待下次提醒安排" }
        if catchUpReminder != nil { return "欢迎回来，稍后提醒你喝一杯水" }
        return "下一次喝水，正在轻轻靠近"
    }

    var weekdaysSummary: String {
        let days = settings.weekdays
        if days.isEmpty { return "未选择提醒日" }
        if days == ReminderWeekday.everyDay { return "每天" }
        if days == ReminderWeekday.workdays { return "周一至周五" }
        if days == ReminderWeekday.weekend { return "周六、周日" }
        return ReminderWeekday.allCases.filter(days.contains).map(Self.weekdayLabel).joined(separator: "、")
    }

    static func weekdayLabel(_ day: ReminderWeekday) -> String {
        switch day {
        case .monday: "周一"; case .tuesday: "周二"; case .wednesday: "周三"; case .thursday: "周四"
        case .friday: "周五"; case .saturday: "周六"; case .sunday: "周日"
        }
    }

    func reschedule(delay: TimeInterval? = nil) {
        now = clock()
        catchUpReminder = nil
        interruptedReminder = false
        regularReminder = settings.isEnabled
            ? settings.schedule.nextReminder(after: now, delay: delay) : nil
        updateNextReminder()
        allowsPreparation = delay == nil
        refreshPreparation()
    }

    private func clearPreparation() {
        preparationPlan = nil
        onDismissPreparation?()
    }

    private func refreshPreparation() {
        clearPreparation()
        guard allowsPreparation, !isScreenUnavailable, !isPresenting, catchUpReminder == nil else { return }
        preparationPlan = PreparationReminderPlan(drinkDate: regularReminder, settings: settings, plannedAt: clock())
    }

    func previewPreparation() {
        guard !isScreenUnavailable, !isPresenting, settings.preparationLeadMinutes > 0 else { return }
        onPresentPreparation?(settings.preparationLeadMinutes)
    }

    private func updateNextReminder() {
        nextReminder = settings.isEnabled && !isScreenUnavailable
            ? [regularReminder, catchUpReminder].compactMap { $0 }.min() : nil
    }

    private func recover(at instant: Date) {
        guard settings.isEnabled else { reschedule(); return }
        let plan = ReminderRecoveryPlan(due: regularReminder, interrupted: interruptedReminder || catchUpReminder != nil,
                                        at: instant, schedule: settings.schedule)
        regularReminder = plan.regularReminder
        catchUpReminder = plan.catchUpReminder
        interruptedReminder = false
        updateNextReminder()
        refreshPreparation()
    }

    func toggleEnabled() {
        settings.isEnabled.toggle()
        if !settings.isEnabled { onDismissReminder?() }
    }

    func recordDrink() {
        now = clock()
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

    func testDrinkVerification() {
        guard !isPresenting, !isScreenUnavailable, let onTestVerification else { return }
        clearPreparation()
        isPresenting = true
        presentingPreview = true
        onTestVerification()
    }

    func finishReminder(_ action: ReminderAction, preview: Bool) {
        isPresenting = false
        if interruptionDismissal {
            interruptionDismissal = false
            // The controller finishes its fade asynchronously. Its system
            // dismissal must not erase the preserved recovery plan.
            if action != .drank { return }
        }
        guard !preview else { refreshPreparation(); return }
        switch action {
        case .drank: recordDrink()
        case .snooze: reschedule(delay: 5 * 60)
        case .dismiss, .emergencyExit: reschedule()
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
                serviceError = "请在「系统设置 → 通用 → 登录项」中允许咕嘟在登录时打开。"
            }
        } catch {
            refreshLoginStatus()
            serviceError = "无法更新登录项：\(error.localizedDescription)\n请先将应用放到「应用程序」文件夹，再试一次。"
        }
    }

    private func present(preview: Bool) {
        guard !isPresenting, !isScreenUnavailable else { return }
        clearPreparation()
        isPresenting = true
        presentingPreview = preview
        if !preview { catchUpReminder = nil; updateNextReminder() }
        onPresentReminder?(preview)
    }

    func tick() {
        let instant = clock()
        let previousTick = lastTick
        let gap = instant.timeIntervalSince(previousTick)
        lastTick = instant
        now = instant
        if gap < -5 { reschedule(); return }
        if gap > 90, !isScreenUnavailable, !isPresenting { recover(at: instant); return }
        guard settings.isEnabled, !isScreenUnavailable, !isPresenting,
              let due = nextReminder else { return }
        if let plan = preparationPlan, lastPreparedReminder != plan.drinkDate,
           plan.shouldPresent(after: previousTick, at: instant) {
            lastPreparedReminder = plan.drinkDate
            onPresentPreparation?(Int(ceil(plan.drinkDate.timeIntervalSince(instant) / 60)))
        }
        guard due <= instant else { return }
        guard settings.schedule.isActive(at: instant) else {
            reschedule()
            return
        }
        if instant.timeIntervalSince(due) >= 90 { recover(at: instant); return }
        reschedule()
        present(preview: false)
    }

    private func availabilityChanged() {
        let unavailable = locked || sleeping || inactiveSession
        guard isScreenUnavailable != unavailable else { return }
        isScreenUnavailable = unavailable
        now = clock()
        lastTick = now
        if unavailable {
            clearPreparation()
            interruptedReminder = interruptedReminder || catchUpReminder != nil || (isPresenting && !presentingPreview)
            catchUpReminder = nil
            interruptionDismissal = isPresenting
            updateNextReminder()
            onDismissReminder?()
        } else { recover(at: now) }
    }

    private func observeSystem() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.displayCount = NSScreen.screens.count
                self?.refreshPreparation()
            }
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

enum ReminderAction { case drank, snooze, dismiss, emergencyExit }
