@preconcurrency import AVFoundation
import AppKit
import Combine
import GuduCore

enum CameraVerificationState: Equatable {
    case idle, authorizing, starting
    case tracking(DrinkVerificationProgress)
    case unavailable(String)
    case verified

    var isUnavailable: Bool {
        if case .unavailable = self { return true }
        return false
    }
}

@MainActor
final class DrinkCameraVerifier: ObservableObject {
    @Published private(set) var state = CameraVerificationState.idle
    @Published private(set) var diagnostics: CupCameraDiagnostics?
    var onVerified: (() -> Void)?
    var onPermissionPrompt: ((Bool) -> Void)?
    var onAttemptStart: (() -> Void)?
    var onUnavailable: (() -> Void)?
    var previewSession: AVCaptureSession? { worker?.session }

    private var worker: CupCameraWorker?
    private var token: UUID?
    private var watchdog: Task<Void, Never>?
    private var startedAt = Date()
    private var lastFrameAt: Date?

    func start() {
        stop()
        onAttemptStart?()
        let token = UUID()
        self.token = token
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: beginCapture(token: token)
        case .notDetermined:
            state = .authorizing
            onPermissionPrompt?(true)
            Task { @MainActor [weak self] in
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                guard let self, self.token == token else { return }
                self.onPermissionPrompt?(false)
                if granted { self.beginCapture(token: token) }
                else { self.reportUnavailable("摄像头权限未获允许。可在系统设置 → 隐私与安全性 → 摄像头中允许咕嘟。") }
            }
        case .denied:
            reportUnavailable("摄像头权限已关闭。请在系统设置 → 隐私与安全性 → 摄像头中允许咕嘟，再重试。")
        case .restricted:
            reportUnavailable("系统限制了摄像头访问，本次无法进行识别。")
        @unknown default:
            reportUnavailable("无法读取摄像头权限状态。")
        }
    }

    func stop(keepState: Bool = false) {
        token = nil
        watchdog?.cancel()
        watchdog = nil
        worker?.stop()
        worker = nil
        onPermissionPrompt?(false)
        if !keepState { state = .idle; diagnostics = nil }
    }

    func reportUnavailable(_ message: String) {
        state = .unavailable(message)
        stop(keepState: true)
        onUnavailable?()
    }

    private func beginCapture(token: UUID) {
        guard self.token == token else { return }
        state = .starting
        startedAt = Date()
        lastFrameAt = nil
        let worker = CupCameraWorker { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, self.token == token else { return }
                switch event {
                case .started:
                    if case .starting = self.state { self.state = .tracking(DrinkVerificationProgress(stage: .findingFace)) }
                case .frame(let progress, let diagnostics):
                    self.lastFrameAt = Date()
                    self.diagnostics = diagnostics
                    if progress.isVerified {
                        self.state = .verified
                        self.stop(keepState: true)
                        self.onVerified?()
                    } else if self.state != .tracking(progress) { self.state = .tracking(progress) }
                case .failed(let message):
                    self.reportUnavailable(message)
                }
            }
        }
        self.worker = worker
        worker.start()
        watchdog = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self, self.token == token else { return }
                if Date().timeIntervalSince(self.lastFrameAt ?? self.startedAt) > 10 {
                    self.reportUnavailable("暂时没有收到摄像头画面。请关闭占用摄像头的应用，检查连接后重试。")
                    return
                }
            }
        }
    }
}
