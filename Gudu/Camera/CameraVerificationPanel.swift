@preconcurrency import AVFoundation
import AppKit
import GuduCore
import SwiftUI

struct CameraVerificationPanel: View {
    @ObservedObject var camera: DrinkCameraVerifier
    var showDiagnostics = false
    var allowsManualConfirmation = false
    @State private var previewAspectRatio: CGFloat = 4.0 / 3.0

    private var previewSize: CGSize {
        // Fit the source's own proportions within the compact preview area.
        // The frame itself changes size, so aspect-fit adds no letterboxing.
        CGSize(width: min(144, 108 * previewAspectRatio),
               height: min(108, 144 / previewAspectRatio))
    }

    var body: some View {
        HStack(spacing: 18) {
            Group {
                if let capture = camera.previewSession, !camera.state.isUnavailable {
                    CameraPreviewView(session: capture) { previewAspectRatio = $0 }
                } else {
                    Image(systemName: camera.state.isUnavailable ? "video.slash" : "camera.fill")
                        .font(.system(size: 25)).foregroundStyle(Palette.mint.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.white.opacity(0.04))
                }
            }
            .frame(width: previewSize.width, height: previewSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel("摄像头完整预览，等比显示，仅在本机处理")
            .help("按视频实际比例显示完整画面，预览框随画幅调整。")
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Circle().fill(camera.state.isUnavailable ? Color.orange : Palette.mint).frame(width: 6, height: 6)
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.mint)
                }
                Text(detail).font(.system(size: 10)).foregroundStyle(Palette.mint.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                if case .tracking(let progress) = camera.state {
                    ProgressView(value: progress.fraction).tint(Palette.mint)
                        .accessibilityLabel("杯子靠近嘴边的识别进度")
                }
                if showDiagnostics, let diagnostics = camera.diagnostics, !diagnostics.crops.isEmpty {
                    CameraDiagnosticsView(diagnostics: diagnostics)
                }
                if camera.state.isUnavailable {
                    Button("重试摄像头") { camera.start() }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.mint)
                } else {
                    Text("本机分析 · 不保存画面 · 不上传")
                        .font(.system(size: 9)).foregroundStyle(Palette.mint.opacity(0.35))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.mint.opacity(0.12), lineWidth: 1))
    }

    private var title: String {
        switch camera.state {
        case .idle: "摄像头尚未启动"
        case .authorizing: "请允许摄像头访问"
        case .starting: "正在打开摄像头…"
        case .unavailable: allowsManualConfirmation ? "摄像头暂不可用，可手动确认" : "摄像头暂时不可用"
        case .verified: "已识别杯子靠近嘴边"
        case .tracking(let progress):
            switch progress.stage {
            case .findingFace: "请面向摄像头"
            case .multiplePeople: "画面中请保持一人"
            case .bringCup: "嘴部位置已记住"
            case .holding: "正在识别喝水…"
            case .verified: "识别完成"
            }
        }
    }

    private var detail: String {
        switch camera.state {
        case .unavailable(let message): allowsManualConfirmation ? "\(message) 喝完后可点击「我喝好了」，也可重试摄像头。" : message
        case .authorizing: "请在 macOS 的授权弹窗中选择允许。"
        case .verified: "即将完成本次提醒。"
        case .tracking(let progress):
            switch progress.stage {
            case .findingFace: "先露出面部定位一次，再正常喝水。"
            case .multiplePeople: "请让画面中只保留一人，再尝试识别。"
            case .bringCup: "正常举杯即可，遮住面部也会保留位置与进度。"
            case .holding:
                progress.isHandAssisted ? "正在结合杯口与手部线索确认，进度会慢一些。" : "正在确认记住位置附近的杯子，无需露出嘴巴。"
            case .verified: "即将完成本次提醒。"
            }
        default: "先定位嘴部，再正常喝水，累计 3 秒有效线索即可完成。"
        }
    }
}

struct CameraDiagnosticsView: View {
    let diagnostics: CupCameraDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(diagnostics.crops.map { "\(name($0.kind)) \(Int($0.vesselConfidence * 100))%" }.joined(separator: " · "))
                .monospacedDigit()
            if let crop = diagnostics.crops.max(by: { $0.vesselConfidence < $1.vesselConfidence }) {
                Text("分类：\(crop.dominantIdentifier.isEmpty ? "暂无" : crop.dominantIdentifier) \(Int(crop.dominantConfidence * 100))% · 手部辅助\(diagnostics.hasHandNearMouth ? "中" : "未启用")")
                    .lineLimit(2)
            }
        }
        .font(.system(size: 10)).foregroundStyle(Palette.mint.opacity(0.65))
        .accessibilityLabel("识别测试的杯具线索分数，分数不是准确率")
    }

    private func name(_ kind: MouthRegion.CropKind) -> String {
        switch kind { case .body: "杯身"; case .rim: "杯口"; case .tilted: "倾斜" }
    }
}

private struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    let onAspectRatioChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> CameraPreviewSurface {
        let view = CameraPreviewSurface()
        view.onAspectRatioChange = onAspectRatioChange
        view.setSession(session)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewSurface, context: Context) {
        nsView.onAspectRatioChange = onAspectRatioChange
        nsView.setSession(session)
        if let connection = nsView.preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        nsView.needsLayout = true
    }

    static func dismantleNSView(_ nsView: CameraPreviewSurface, coordinator: ()) {
        nsView.setSession(nil)
        nsView.onAspectRatioChange = nil
    }
}

private final class CameraPreviewSurface: NSView {
    let preview = AVCaptureVideoPreviewLayer()
    var onAspectRatioChange: ((CGFloat) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var lastAspectRatio: CGFloat?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        // Size the outer view to the actual picture; keep the full field of view.
        preview.videoGravity = .resizeAspect
        layer?.addSublayer(preview)
    }
    required init?(coder: NSCoder) { nil }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func setSession(_ session: AVCaptureSession?) {
        guard preview.session !== session else { return }
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        lastAspectRatio = nil
        preview.session = session
        guard let session else { return }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVCaptureSession.didStartRunningNotification,
                                            object: session, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.needsLayout = true }
        })
        observers.append(center.addObserver(forName: AVCaptureInput.Port.formatDescriptionDidChangeNotification,
                                            object: nil, queue: .main) { [weak self] notification in
            guard let port = notification.object as? AVCaptureInput.Port else { return }
            Task { @MainActor [weak self] in
                guard let self, self.preview.connection?.inputPorts.contains(where: { $0 === port }) == true else { return }
                self.needsLayout = true
            }
        })
        needsLayout = true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        preview.frame = bounds
        CATransaction.commit()
        reportAspectRatio()
    }

    private func reportAspectRatio() {
        guard let session = preview.session, session.isRunning,
              preview.connection?.inputPorts.contains(where: { $0.formatDescription != nil }) == true,
              bounds.width > 0, bounds.height > 0 else { return }
        // Ask this preview layer for the complete picture's rectangle. Its
        // source may differ from the 640x480 buffer delivered to Vision.
        let picture = preview.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard picture.width.isFinite, picture.height.isFinite, picture.width > 0, picture.height > 0 else { return }
        let ratio = picture.width / picture.height
        guard ratio.isFinite, ratio > 0,
              lastAspectRatio.map({ abs($0 - ratio) > 0.001 }) ?? true else { return }
        lastAspectRatio = ratio
        // SwiftUI must receive the new size outside its current layout/update.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.preview.session === session, self.lastAspectRatio == ratio else { return }
            self.onAspectRatioChange?(ratio)
        }
    }
}
