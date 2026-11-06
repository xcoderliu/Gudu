import AppKit
import ImageIO
import RippleCore
import SwiftUI
import UniformTypeIdentifiers

/// Render the real vector scene for motion review without recording a screen.
@main
struct MotionRenderer {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let size = NSSize(width: 800, height: 380)
        let hosting = NSHostingView(rootView: AnyView(EmptyView()))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        defer { window.close() }

        func render<Content: View>(_ content: Content, size: NSSize) throws -> NSBitmapImageRep {
            window.setContentSize(size)
            hosting.rootView = AnyView(content.environment(\.rippleStaticAnimation, true))
            hosting.setFrameSize(size)
            hosting.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.025))
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
                throw NSError(domain: "RippleMotion", code: 1)
            }
            bitmap.size = size
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            return bitmap
        }

        let frameCount = 108
        let gifURL = output.appendingPathComponent("pickup-motion.gif")
        guard let gif = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else {
            throw NSError(domain: "RippleMotion", code: 2)
        }
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<frameCount {
            let progress = Double(frame) / Double(frameCount - 1)
            let time = 2.7 + progress * 4.5
            let opacity = min(1, min(progress / 0.05, (1 - progress) / 0.05))
            let scene = DrinkingRitualScene(startedAt: .now, snapshotTime: time)
                .frame(width: size.width, height: size.height).opacity(opacity)
                .background(Palette.ocean).id(frame)
            let bitmap = try render(scene, size: size)
            guard let image = bitmap.cgImage else { throw NSError(domain: "RippleMotion", code: 3) }
            CGImageDestinationAddImage(gif, image, [kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: 1.0 / 24,
                kCGImagePropertyGIFUnclampedDelayTime: 1.0 / 24
            ]] as CFDictionary)
        }
        guard CGImageDestinationFinalize(gif) else { throw NSError(domain: "RippleMotion", code: 4) }

        let times = [3.8, 4.2, 4.6, 4.9, 5.7, 6.7]
        let contact = VStack(spacing: 16) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { column in
                        let time = times[row * 3 + column]
                        VStack(spacing: 8) {
                            DrinkingRitualScene(startedAt: .now, snapshotTime: time).frame(width: 420, height: 220)
                            Text(String(format: "%.1f s", time)).font(.system(size: 13)).foregroundStyle(Palette.mint)
                        }
                    }
                }
            }
        }.padding(20).background(Palette.ocean)
        let contactBitmap = try render(contact, size: NSSize(width: 1324, height: 550))
        try contactBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("pickup-frames.png"))
        print("Rendered \(gifURL.path) and pickup-frames.png")

        let confettiSize = NSSize(width: 960, height: 600)
        let confettiURL = output.appendingPathComponent("confetti-motion.gif")
        guard let confetti = CGImageDestinationCreateWithURL(confettiURL as CFURL, UTType.gif.identifier as CFString, 72, nil) else {
            throw NSError(domain: "RippleMotion", code: 5)
        }
        CGImageDestinationSetProperties(confetti, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<72 {
            let scene = ConfettiCelebrationView(startedAt: .now, preview: true, snapshotTime: Double(frame) / 24)
                .frame(width: confettiSize.width, height: confettiSize.height)
                .background(LinearGradient(colors: [Color(hex: 0x26384C), Color(hex: 0x496367)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .id(frame)
            let bitmap = try render(scene, size: confettiSize)
            guard let image = bitmap.cgImage else { throw NSError(domain: "RippleMotion", code: 6) }
            CGImageDestinationAddImage(confetti, image, [kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: 1.0 / 24,
                kCGImagePropertyGIFUnclampedDelayTime: 1.0 / 24
            ]] as CFDictionary)
        }
        guard CGImageDestinationFinalize(confetti) else { throw NSError(domain: "RippleMotion", code: 7) }
        for still in [false, true] {
            let scene = ConfettiCelebrationView(startedAt: .now, snapshotTime: 1, snapshotReduceMotion: still)
                .frame(width: 1440, height: 900)
            let bitmap = try render(scene, size: NSSize(width: 1440, height: 900))
            let name = still ? "confetti-reduce-motion.png" : "confetti-transparent.png"
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
        }
        print("Rendered \(confettiURL.path), confetti-transparent.png, and confetti-reduce-motion.png")
    }
}
