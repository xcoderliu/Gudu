@preconcurrency import AVFoundation
import AppKit
import RippleCore
import SwiftUI

struct CameraVerificationPanel: View {
    @ObservedObject var camera: DrinkCameraVerifier

    var body: some View {
        HStack(spacing: 18) {
            Group {
                if let capture = camera.previewSession, !camera.state.isUnavailable {
                    CameraPreviewView(session: capture)
                } else {
                    Image(systemName: camera.state.isUnavailable ? "video.slash" : "camera.fill")
                        .font(.system(size: 25)).foregroundStyle(Palette.mint.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.white.opacity(0.04))
                }
            }
            .frame(width: 140, height: 96).clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel("摄像头实时预览，仅在本机处理")
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
        case .unavailable: "摄像头暂时不可用"
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
        case .unavailable(let message): message
        case .authorizing: "请在 macOS 的授权弹窗中选择允许。"
        case .verified: "即将完成本次提醒。"
        case .tracking(let progress):
            switch progress.stage {
            case .findingFace: "先露出面部定位一次，再正常喝水。"
            case .multiplePeople: "请让画面中只保留一人，再尝试识别。"
            case .bringCup: "正常举杯即可，遮住面部也会保留位置与进度。"
            case .holding: "正在确认记住位置附近的杯子，无需露出嘴巴。"
            case .verified: "即将完成本次提醒。"
            }
        default: "先定位嘴部，再正常喝水，累计识别 1.2 秒即可完成。"
        }
    }
}

private struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    func makeNSView(context: Context) -> CameraPreviewSurface {
        let view = CameraPreviewSurface()
        view.preview.session = session
        return view
    }
    func updateNSView(_ nsView: CameraPreviewSurface, context: Context) {
        if nsView.preview.session !== session { nsView.preview.session = session }
        if let connection = nsView.preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}

private final class CameraPreviewSurface: NSView {
    let preview = AVCaptureVideoPreviewLayer()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        preview.videoGravity = .resizeAspectFill
        layer?.addSublayer(preview)
    }
    required init?(coder: NSCoder) { nil }
    override func layout() { super.layout(); preview.frame = bounds }
}
