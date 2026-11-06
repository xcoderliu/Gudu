@preconcurrency import AVFoundation
import Foundation
import QuartzCore
import RippleCore
import Vision

enum CupCameraEvent: Sendable {
    case started
    case frame(DrinkVerificationProgress)
    case failed(String)
}

/// Capture configuration and Vision run on separate serial queues. Stopping a
/// session from its own frame callback can deadlock, so stop uses captureQueue.
final class CupCameraWorker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "local.ripple.camera.capture", qos: .userInitiated)
    private let visionQueue = DispatchQueue(label: "local.ripple.camera.vision", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private let lock = NSLock()
    private var active = true
    private let onEvent: @Sendable (CupCameraEvent) -> Void
    private var observers: [NSObjectProtocol] = [] // captureQueue only
    private let faceRequest = VNDetectFaceLandmarksRequest()
    private let vesselRequest = VNClassifyImageRequest()
    private var detector = DrinkGestureDetector() // visionQueue only
    private var lastAnalysis = -Double.infinity
    private var consecutiveErrors = 0

    init(onEvent: @escaping @Sendable (CupCameraEvent) -> Void) {
        self.onEvent = onEvent
        super.init()
        vesselRequest.revision = VNClassifyImageRequestRevision1
    }

    private var isActive: Bool {
        lock.lock(); defer { lock.unlock() }
        return active
    }

    func start() {
        captureQueue.async { [self] in
            guard isActive else { return }
            do {
                guard let device = AVCaptureDevice.default(for: .video) else {
                    fail("未找到摄像头。请连接摄像头后重试。")
                    return
                }
                let input = try AVCaptureDeviceInput(device: device)
                session.beginConfiguration()
                if session.canSetSessionPreset(.vga640x480) { session.sessionPreset = .vga640x480 }
                guard session.canAddInput(input), session.canAddOutput(output) else {
                    session.commitConfiguration()
                    fail("无法建立摄像头会话，请检查其他应用是否正在使用摄像头。")
                    return
                }
                session.addInput(input)
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.setSampleBufferDelegate(self, queue: visionQueue)
                session.addOutput(output)
                session.commitConfiguration()
                let center = NotificationCenter.default
                for name in [AVCaptureSession.runtimeErrorNotification, AVCaptureSession.wasInterruptedNotification] {
                    observers.append(center.addObserver(forName: name, object: session, queue: nil) { [weak self] _ in
                        self?.fail("摄像头会话被中断。请检查摄像头连接或其他应用后重试。")
                    })
                }
                guard isActive else { return }
                session.startRunning()
                if isActive { onEvent(.started) }
            } catch { fail("无法打开摄像头：\(error.localizedDescription)") }
        }
    }

    func stop() {
        lock.lock(); active = false; lock.unlock()
        captureQueue.async { [self] in
            output.setSampleBufferDelegate(nil, queue: nil)
            if session.isRunning { session.stopRunning() }
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
        }
    }

    private func fail(_ message: String) {
        lock.lock()
        let shouldReport = active
        active = false
        lock.unlock()
        if shouldReport { onEvent(.failed(message)); stop() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = CACurrentMediaTime()
        guard isActive, time - lastAnalysis >= 1.0 / 6,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysis = time
        do {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up)
            try handler.perform([faceRequest])
            let faces = (faceRequest.results ?? []).filter { $0.confidence >= 0.5 }
            var sample = DrinkGestureSample(faceCount: faces.count, faceConfidence: 0, vesselConfidence: 0)
            if faces.count == 1, let face = faces.first {
                sample.faceConfidence = Double(face.confidence)
                let mouth = Self.mouthPosition(face)
                let aspect = CGFloat(CVPixelBufferGetWidth(pixels)) / CGFloat(CVPixelBufferGetHeight(pixels))
                // Only classify immediately around/below the mouth. A mug on a
                // desk elsewhere in the frame must not satisfy the reminder.
                if let region = MouthRegion.boundingBox(mouth: mouth, faceWidth: face.boundingBox.width, imageAspectRatio: aspect) {
                    vesselRequest.regionOfInterest = region
                    try handler.perform([vesselRequest])
                    sample.vesselConfidence = Double((vesselRequest.results ?? [])
                        .filter { DrinkingVesselLabels.accepts($0.identifier) }
                        .map(\.confidence).max() ?? 0)
                }
            }
            consecutiveErrors = 0
            let progress = detector.consume(sample, at: time)
            if isActive { onEvent(.frame(progress)) }
        } catch {
            consecutiveErrors += 1
            if consecutiveErrors >= 5 { fail("暂时无法分析画面，请改善光线或调整摄像头后重试。") }
        }
    }

    private static func mouthPosition(_ face: VNFaceObservation) -> CGPoint {
        let box = face.boundingBox
        if let lips = face.landmarks?.outerLips, lips.pointCount > 0 {
            let sum = lips.normalizedPoints.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            return CGPoint(x: box.minX + sum.x / CGFloat(lips.pointCount) * box.width,
                           y: box.minY + sum.y / CGFloat(lips.pointCount) * box.height)
        }
        // Cups often occlude lip landmarks; the detected face still anchors ROI.
        return CGPoint(x: box.midX, y: box.minY + box.height * 0.3)
    }
}
