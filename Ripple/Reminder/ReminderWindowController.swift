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
    let character: ReminderCharacter
    @Published var completed = false

    init(preview: Bool, servingML: Int, seconds: Int, character: ReminderCharacter = .neutral) {
        isPreview = preview
        self.servingML = servingML
        self.character = character
        deadline = seconds > 0 ? Date().addingTimeInterval(Double(seconds)) : nil
    }
}

@MainActor
final class ReminderWindowController {
    private let model: AppModel
    private(set) var panels: [ReminderPanel] = []
    private var session: ReminderSession?
    private var keyMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var autoDismissTask: Task<Void, Never>?
    private var completionTask: Task<Void, Never>?
    private var finishing = false
    private var closing = false
    private var audioPlayer: AVAudioPlayer?

    init(model: AppModel) {
        self.model = model
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss(action: .dismiss) }
        }
    }

    func present(preview: Bool) {
        guard panels.isEmpty else { return }
        let screens = NSScreen.screens
        let cursor = NSEvent.mouseLocation
        let indices = ScreenRouter.targetIndices(cursor: cursor, frames: screens.map(\.frame), mode: model.settings.displayMode)
        guard !indices.isEmpty else {
            model.finishReminder(.dismiss, preview: preview)
            return
        }
        let session = ReminderSession(preview: preview, servingML: model.settings.servingML,
                                      seconds: model.settings.autoDismissSeconds, character: model.settings.character)
        self.session = session
        finishing = false
        closing = false

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
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        // Key only the panel under the pointer. Other displays stay synchronized.
        let active = panels.first { $0.frame.contains(cursor) } ?? panels.first
        active?.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.45
            panels.forEach { $0.animator().alphaValue = 1 }
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !self.panels.isEmpty else { return event }
            if event.keyCode == 53 { self.handle(.dismiss); return nil }
            if event.keyCode == 36 || event.keyCode == 76 { self.handle(.drank); return nil }
            return event
        }
        if model.settings.soundEnabled {
            let still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            playSound(still ? "Satisfied" : "HydrationRitual", loop: !still)
        }
        if model.settings.autoDismissSeconds > 0 {
            let seconds = model.settings.autoDismissSeconds
            autoDismissTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                self?.dismiss(action: .dismiss)
            }
        }
    }

    private func handle(_ action: ReminderAction) {
        guard !finishing, !closing else { return }
        if case .drank = action {
            finishing = true
            autoDismissTask?.cancel()
            if model.settings.soundEnabled { playSound("Satisfied") }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { session?.completed = true }
            completionTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                self?.dismiss(action: .drank)
            }
        } else { dismiss(action: action) }
    }

    func dismiss(action: ReminderAction) {
        guard let session, !closing else { return }
        closing = true
        autoDismissTask?.cancel()
        completionTask?.cancel()
        audioPlayer?.stop()
        audioPlayer = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        let windows = panels
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.25
            windows.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                windows.forEach { $0.close() }
                self?.panels.removeAll()
                self?.session = nil
                self?.finishing = false
                self?.closing = false
                self?.model.finishReminder(action, preview: session.isPreview)
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
