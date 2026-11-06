import AppKit
import AVFoundation
import RippleCore
import SwiftUI

@MainActor
final class ReminderSession: ObservableObject {
    let isPreview: Bool
    let servingML: Int
    let deadline: Date?
    let startedAt = Date()
    let completionGate: ReminderCompletionGate
    let camera = DrinkCameraVerifier()
    @Published var completed = false
    @Published var verificationPassed = false
    @Published var askToExit = false
    @Published var isHoldingEscape = false
    var requiresVerification: Bool { completionGate.requiresVerification }

    init(preview: Bool, servingML: Int, seconds: Int,
         requiresVerification: Bool = false) {
        isPreview = preview
        self.servingML = servingML
        let gate = ReminderCompletionGate(requiresVerification: requiresVerification)
        completionGate = gate
        deadline = seconds > 0 && gate.allowsAutoDismiss ? Date().addingTimeInterval(Double(seconds)) : nil
    }
}

@MainActor
final class ReminderWindowController {
    private let model: AppModel
    private let presentsWindows: Bool
    private(set) var panels: [ReminderPanel] = []
    private(set) var celebrationPanels: [CelebrationPanel] = []
    private var session: ReminderSession?
    private var keyMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var autoDismissTask: Task<Void, Never>?
    private var celebrationTask: Task<Void, Never>?
    private var shouldCelebrateCompletion = false
    private var finishing = false
    private var closing = false
    private var audioPlayer: AVAudioPlayer?
    private var escapeTask: Task<Void, Never>?

    init(model: AppModel, presentsWindows: Bool = true) {
        self.model = model
        self.presentsWindows = presentsWindows
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss(action: .dismiss) }
        }
    }

    func present(preview: Bool, testVerification: Bool = false) {
        guard panels.isEmpty else { return }
        stopCelebration()
        let screens = NSScreen.screens
        let cursor = NSEvent.mouseLocation
        let indices = ScreenRouter.targetIndices(cursor: cursor, frames: screens.map(\.frame), mode: model.settings.displayMode)
        guard !indices.isEmpty else {
            model.finishReminder(.dismiss, preview: preview)
            return
        }
        let session = ReminderSession(preview: preview, servingML: model.settings.servingML,
                                      seconds: model.settings.autoDismissSeconds,
                                      requiresVerification: testVerification || (!preview && model.settings.requireDrinkVerification))
        self.session = session
        finishing = false
        closing = false
        shouldCelebrateCompletion = false

        for index in indices {
            let screen = screens[index]
            let panel = ReminderPanel(contentRect: screen.frame,
                                      styleMask: [.borderless, .nonactivatingPanel],
                                      backing: .buffered, defer: false, screen: screen)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            if #available(macOS 15.0, *) { panel.collectionBehavior.insert(.canJoinAllApplications) }
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.isOpaque = true
            panel.hasShadow = false
            panel.backgroundColor = NSColor(Palette.ocean)
            panel.animationBehavior = .none
            panel.setAccessibilityTitle(preview ? "澄水动画预览" : "澄水喝水提醒")
            panel.contentView = NSHostingView(rootView: ReminderView(session: session) { [weak self] action in
                self?.handle(action)
            })
            panel.setFrame(screen.frame, display: true)
            panel.alphaValue = 0
            if presentsWindows { panel.orderFrontRegardless() }
            panels.append(panel)
        }
        // Key only the panel under the pointer. Other displays stay synchronized.
        let active = panels.first { $0.frame.contains(cursor) } ?? panels.first
        if presentsWindows { active?.makeKey() }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.45
            panels.forEach { $0.animator().alphaValue = 1 }
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self, !self.panels.isEmpty else { return event }
            if event.keyCode == 53 { self.handleEscape(event); return nil }
            if event.type == .keyDown && (event.keyCode == 36 || event.keyCode == 76) {
                self.handle(.drank); return nil
            }
            return event
        }
        if model.settings.soundEnabled {
            let still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            playSound(still ? "Satisfied" : "HydrationRitual", loop: !still && !session.requiresVerification)
        }
        if session.requiresVerification {
            session.camera.onPermissionPrompt = { [weak self] prompting in
                // A screen-saver-level overlay must not cover the macOS consent alert.
                self?.panels.forEach { $0.level = prompting ? .normal : .screenSaver }
                if prompting { NSApp.activate(ignoringOtherApps: true) }
            }
            session.camera.onVerified = { [weak self, weak session] in
                guard let self, let session, self.session === session else { return }
                session.verificationPassed = true
                self.handle(.drank)
            }
            session.camera.start()
        } else if session.completionGate.allowsAutoDismiss && model.settings.autoDismissSeconds > 0 {
            let seconds = model.settings.autoDismissSeconds
            autoDismissTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                self?.dismiss(action: .dismiss)
            }
        }
    }

    private func handle(_ action: ReminderAction) {
        guard let session, !finishing, !closing else { return }
        if case .dismiss = action, session.requiresVerification && !session.isPreview {
            session.askToExit = true
            return
        }
        if case .snooze = action, !session.completionGate.allowsSnooze { return }
        if case .drank = action {
            guard session.completionGate.allowsCompletion(verified: session.verificationPassed) else { return }
            finishing = true
            autoDismissTask?.cancel()
            session.camera.stop(keepState: true)
            session.completed = true
            shouldCelebrateCompletion = true
            dismiss(action: .drank)
        } else { dismiss(action: action) }
    }

    func dismiss(action: ReminderAction) {
        stopCelebration()
        guard let session else { return }
        if closing {
            // A lock, sleep, display change, or opt-out during the fade cancels
            // the decoration without changing an already accepted drink.
            shouldCelebrateCompletion = false
            return
        }
        closing = true
        autoDismissTask?.cancel()
        escapeTask?.cancel()
        escapeTask = nil
        session.camera.stop()
        audioPlayer?.stop()
        audioPlayer = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        let windows = panels
        let targetFrames = windows.map(\.frame)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.25
            windows.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                windows.forEach { $0.close() }
                guard let self else { return }
                self.panels.removeAll()
                self.session = nil
                self.finishing = false
                self.closing = false
                if self.shouldCelebrateCompletion && !self.model.isScreenUnavailable {
                    self.showCelebration(on: targetFrames, preview: session.isPreview, servingML: session.servingML)
                }
                self.shouldCelebrateCompletion = false
                self.model.finishReminder(action, preview: session.isPreview)
            }
        }
    }

    func shutdown() {
        shouldCelebrateCompletion = false
        session?.camera.stop()
        escapeTask?.cancel()
        stopCelebration()
    }

    private func showCelebration(on targetFrames: [CGRect], preview: Bool, servingML: Int) {
        let startedAt = Date()
        for screen in NSScreen.screens where targetFrames.contains(screen.frame) {
            let panel = CelebrationPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                         backing: .buffered, defer: false, screen: screen)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            if #available(macOS 15.0, *) { panel.collectionBehavior.insert(.canJoinAllApplications) }
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.animationBehavior = .none
            panel.contentView = NSHostingView(rootView: ConfettiCelebrationView(startedAt: startedAt,
                                                                               preview: preview, servingML: servingML))
            panel.setFrame(screen.frame, display: true)
            if presentsWindows { panel.orderFrontRegardless() }
            celebrationPanels.append(panel)
        }
        guard !celebrationPanels.isEmpty else { return }
        if model.settings.soundEnabled { playSound("Satisfied") }
        let duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 1.4 : ConfettiCelebrationView.duration
        celebrationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.stopCelebration()
        }
    }

    private func stopCelebration() {
        if !celebrationPanels.isEmpty { audioPlayer?.stop(); audioPlayer = nil }
        celebrationTask?.cancel()
        celebrationTask = nil
        celebrationPanels.forEach { $0.close() }
        celebrationPanels.removeAll()
    }

    func cancelVerification() {
        if session?.requiresVerification == true { dismiss(action: .emergencyExit) }
    }

    private func handleEscape(_ event: NSEvent) {
        guard let session else { return }
        guard session.requiresVerification && !session.isPreview else {
            if event.type == .keyDown { handle(.dismiss) }
            return
        }
        if event.type == .keyUp {
            escapeTask?.cancel(); escapeTask = nil; session.isHoldingEscape = false
        } else if !event.isARepeat && escapeTask == nil {
            session.isHoldingEscape = true
            escapeTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self?.dismiss(action: .emergencyExit)
            }
        }
    }

    private func playSound(_ name: String, loop: Bool = false) {
        audioPlayer?.stop()
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = 0.55
        player.numberOfLoops = loop ? -1 : 0
        player.prepareToPlay()
        player.play()
        audioPlayer = player
    }
}

final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class CelebrationPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
