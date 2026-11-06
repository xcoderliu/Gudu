@preconcurrency import AVFoundation
import Foundation
import CoreImage
import QuartzCore
import RippleCore
import Vision

enum CupCameraEvent: Sendable {
    case started
    case frame(DrinkVerificationProgress, CupCameraDiagnostics)
    case failed(String)
}

struct CupCropClassification: Sendable, Equatable {
    let kind: MouthRegion.CropKind
    let vesselConfidence: Double
    let dominantIdentifier: String
    let dominantConfidence: Double
}

/// Ephemeral scores and labels for the explicit recognition test, never frames.
struct CupCameraDiagnostics: Sendable, Equatable {
    let crops: [CupCropClassification]
    let hasHandNearMouth: Bool
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
    private let handRequest = VNDetectHumanHandPoseRequest()
    private let vesselRequest = VNClassifyImageRequest()
    private let cropContext = CIContext(options: [.cacheIntermediates: false])
    private var mouthMemory = MouthPositionMemory()
    private var detector = DrinkGestureDetector() // visionQueue only
    private var lastAnalysis = -Double.infinity
    private var consecutiveErrors = 0

    init(onEvent: @escaping @Sendable (CupCameraEvent) -> Void) {
        self.onEvent = onEvent
        super.init()
        vesselRequest.revision = VNClassifyImageRequestRevision1
        handRequest.maximumHandCount = 2
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
            let aspect = CGFloat(CVPixelBufferGetWidth(pixels)) / CGFloat(CVPixelBufferGetHeight(pixels))
            if mouthMemory.anchor == nil, faces.count == 1, let face = faces.first,
               let mouth = Self.visibleMouthPosition(face) {
                mouthMemory.remember(face: face.boundingBox, mouth: mouth)
            }
            var classifications: [CupCropClassification] = []
            if let anchor = mouthMemory.anchor {
                // These views retain the cup body, visible rim, and tilted glass
                // separately. Never require a handle or currently visible lips.
                for crop in MouthRegion.classificationCrops(mouth: anchor.mouth, faceWidth: anchor.faceWidth, imageAspectRatio: aspect) {
                    classifications.append(try classify(in: pixels, crop: crop))
                    if classifications.last!.vesselConfidence >= DrinkingVesselEvidence.clearThreshold { break }
                }
            }
            let evidence = DrinkingVesselEvidence(cropConfidences: classifications.map(\.vesselConfidence))
            var handNearMouth = false
            if !evidence.isClear, evidence.supportsHandAssistance, let anchor = mouthMemory.anchor {
                // Hand pose is optional support for weak *cup* evidence. If it
                // fails, direct cup classification remains available next frame.
                if (try? handler.perform([handRequest])) != nil {
                    handNearMouth = (handRequest.results ?? []).contains { hand in
                        guard let points = try? hand.recognizedPoints(.all) else { return false }
                        let joints = points.values.filter { $0.confidence >= 0.3 }.map(\.location)
                        return MouthRegion.hasNearbyHand(joints: joints, mouth: anchor.mouth,
                                                         faceWidth: anchor.faceWidth, imageAspectRatio: aspect)
                    }
                }
            }
            let sample = DrinkGestureSample(faceCount: faces.count, hasRememberedMouth: mouthMemory.anchor != nil,
                                             vesselConfidence: evidence.strongest,
                                             corroboratingVesselConfidence: evidence.corroborating,
                                             hasHandNearMouth: handNearMouth)
            let progress = detector.consume(sample, at: time)
            // Freeze even a partial cup location. With no cup evidence, update
            // clear face coordinates for the next frame without classifying twice.
            if evidence.strongest < DrinkingVesselEvidence.partialThreshold, faces.count == 1, let face = faces.first,
               let mouth = Self.visibleMouthPosition(face) {
                mouthMemory.remember(face: face.boundingBox, mouth: mouth)
            }
            consecutiveErrors = 0
            if isActive { onEvent(.frame(progress, CupCameraDiagnostics(crops: classifications, hasHandNearMouth: handNearMouth))) }
        } catch {
            consecutiveErrors += 1
            if consecutiveErrors >= 5 { fail("暂时无法分析画面，请改善光线或调整摄像头后重试。") }
        }
    }

    private func classify(in pixels: CVPixelBuffer, crop: MouthRegion.Crop) throws -> CupCropClassification {
        let image = CIImage(cvPixelBuffer: pixels)
        let region = crop.bounds
        let rectangle = CGRect(x: region.minX * image.extent.width, y: region.minY * image.extent.height,
                               width: region.width * image.extent.width, height: region.height * image.extent.height)
            .integral.intersection(image.extent)
        guard let imageCrop = cropContext.createCGImage(image, from: rectangle) else {
            return CupCropClassification(kind: crop.kind, vesselConfidence: 0, dominantIdentifier: "", dominantConfidence: 0)
        }
        // Materialize each crop, so the classifier sees only this patch of pixels
        // rather than depending on a request's interpretation of regionOfInterest.
        try VNImageRequestHandler(cgImage: imageCrop, orientation: .up).perform([vesselRequest])
        let results = vesselRequest.results ?? []
        let vessel = results.filter { DrinkingVesselLabels.accepts($0.identifier) }.map(\.confidence).max() ?? 0
        let dominant = results.max { $0.confidence < $1.confidence }
        return CupCropClassification(kind: crop.kind, vesselConfidence: Double(vessel),
                                     dominantIdentifier: dominant?.identifier ?? "", dominantConfidence: Double(dominant?.confidence ?? 0))
    }

    private static func visibleMouthPosition(_ face: VNFaceObservation) -> CGPoint? {
        let box = face.boundingBox
        let hasEye = (face.landmarks?.leftEye?.pointCount ?? 0) >= 2 || (face.landmarks?.rightEye?.pointCount ?? 0) >= 2
        if hasEye, let lips = face.landmarks?.outerLips, lips.pointCount >= 4 {
            let sum = lips.normalizedPoints.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            return CGPoint(x: box.minX + sum.x / CGFloat(lips.pointCount) * box.width,
                           y: box.minY + sum.y / CGFloat(lips.pointCount) * box.height)
        }
        return nil
    }
}
