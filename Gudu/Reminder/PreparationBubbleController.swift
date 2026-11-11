import AppKit
import GuduCore
import SwiftUI

/// A short, non-key panel, independent of camera verification and drink history.
@MainActor
final class PreparationBubbleController {
    private(set) var panels: [PreparationBubblePanel] = []
    private var dismissal: Task<Void, Never>?
    private let presentsWindows: Bool

    init(presentsWindows: Bool = true) { self.presentsWindows = presentsWindows }

    func present(minutes: Int, mode: DisplayMode) {
        dismiss()
        let screens = NSScreen.screens
        let indices = ScreenRouter.targetIndices(cursor: NSEvent.mouseLocation,
                                                  frames: screens.map(\.frame), mode: mode)
        for index in indices {
            let screen = screens[index]
            let visible = screen.visibleFrame
            let size = NSSize(width: min(340, visible.width - 24), height: 100)
            let frame = NSRect(x: visible.maxX - size.width - 12, y: visible.maxY - size.height - 12,
                               width: size.width, height: size.height)
            let panel = PreparationBubblePanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                               backing: .buffered, defer: false, screen: screen)
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            if #available(macOS 15.0, *) { panel.collectionBehavior.insert(.canJoinAllApplications) }
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.animationBehavior = .none
            panel.setAccessibilityTitle("咕嘟接水提醒")
            let hosting = NSHostingView(rootView: PreparationBubbleView(minutes: minutes) { [weak self] in self?.dismiss() }
                .frame(width: size.width, height: size.height))
            // A floating banner owns its dimensions. The default hosting sizing
            // options otherwise propagate a delayed minimum height to NSPanel.
            hosting.sizingOptions = []
            hosting.frame = NSRect(origin: .zero, size: size)
            hosting.autoresizingMask = [.width, .height]
            panel.contentView = hosting
            panel.contentMinSize = size
            panel.contentMaxSize = size
            panel.setFrame(frame, display: false)
            panels.append(panel)
            if presentsWindows {
                panel.alphaValue = 0
                panel.orderFrontRegardless()
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.2
                    panel.animator().alphaValue = 1
                }
            }
        }
        dismissal = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissal?.cancel()
        dismissal = nil
        panels.forEach { $0.orderOut(nil); $0.close() }
        panels.removeAll()
    }
}

final class PreparationBubblePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

struct PreparationBubbleView: View {
    let minutes: Int
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(Palette.mint.opacity(0.5))
                Image(systemName: "mug.fill")
                    .font(.system(size: 19, weight: .medium)).foregroundStyle(Palette.accent)
                Image(systemName: "drop.fill")
                    .font(.system(size: 7)).foregroundStyle(Palette.accent)
                    .offset(x: 2, y: -14)
            }.frame(width: 36, height: 40).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("可以接水了哟～")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                Text("\(minutes) 分钟后，该咕嘟一口啦")
                    .font(.system(size: 11.5)).foregroundStyle(Palette.secondary)
            }.lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.secondary.opacity(0.8)).frame(width: 20, height: 20)
                    .contentShape(Circle())
            }.buttonStyle(.plain).accessibilityLabel("关闭接水提醒")
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(Palette.line, lineWidth: 0.75))
        .padding(8)
        .environment(\.colorScheme, .light)
    }
}
