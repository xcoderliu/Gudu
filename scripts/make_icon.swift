#!/usr/bin/env swift
// Native vector drawing for the app icon; animation artwork lives in WaterScene.
import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let output = root.appendingPathComponent("Ripple/Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func render(pixels: Int, to url: URL) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let background = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 207, yRadius: 207)
    NSGradient(starting: color(0x153C3B), ending: color(0x32866C))!.draw(in: background, angle: 50)
    for (index, rect) in [NSRect(x: 252, y: 256, width: 520, height: 146), NSRect(x: 190, y: 219, width: 644, height: 214)].enumerated() {
        color(0xB6E5CF).withAlphaComponent(index == 0 ? 0.34 : 0.16).setStroke()
        let ring = NSBezierPath(ovalIn: rect)
        ring.lineWidth = 9
        ring.stroke()
    }
    let drop = NSBezierPath()
    drop.move(to: NSPoint(x: 512, y: 809))
    drop.curve(to: NSPoint(x: 512, y: 305), controlPoint1: NSPoint(x: 579, y: 701), controlPoint2: NSPoint(x: 895, y: 320))
    drop.curve(to: NSPoint(x: 512, y: 809), controlPoint1: NSPoint(x: 129, y: 320), controlPoint2: NSPoint(x: 445, y: 701))
    drop.close()
    NSGradient(starting: color(0x9DDCB7), ending: color(0xE1F7D7))!.draw(in: drop, angle: 110)
    color(0xFFFFFF).withAlphaComponent(0.6).setStroke()
    let shine = NSBezierPath()
    shine.move(to: NSPoint(x: 408, y: 466))
    shine.curve(to: NSPoint(x: 395, y: 561), controlPoint1: NSPoint(x: 380, y: 480), controlPoint2: NSPoint(x: 378, y: 524))
    shine.lineWidth = 24
    shine.lineCapStyle = .round
    shine.stroke()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(size)x\(size)@\(scale)x.png"
        try render(pixels: size * scale, to: output.appendingPathComponent(filename))
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": filename])
    }
}
let json = try JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "xcode", "version": 1]], options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("Contents.json"))
print("Generated app icon at \(output.path)")
