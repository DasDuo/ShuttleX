#!/usr/bin/env swift
import AppKit

// Generates the AppIcon .iconset PNGs from the same shuttle silhouette used in
// the app (white glyph on a blue→indigo rounded square). Run via build-icon.sh.

enum Seg {
    case move(Double, Double)
    case line(Double, Double)
    case curve(Double, Double, Double, Double, Double, Double)
}

// Side view of the orbiter, nose right (design space 100×100, y down).
let segments: [Seg] = [
    .move(95, 54),
    .curve(76, 45, 93, 48, 86, 45),
    .line(38, 42), .line(24, 18), .line(16, 43), .line(8, 49), .line(8, 60),
    .line(28, 62), .line(33, 82), .line(58, 62), .line(84, 60),
    .curve(95, 54, 90, 59, 95, 57),
]

func shuttlePath(in rect: NSRect) -> NSBezierPath {
    func p(_ x: Double, _ y: Double) -> NSPoint {
        NSPoint(x: rect.minX + CGFloat(x) / 100 * rect.width,
                y: rect.maxY - CGFloat(y) / 100 * rect.height) // flip y (AppKit is y-up)
    }
    let path = NSBezierPath()
    for seg in segments {
        switch seg {
        case let .move(x, y): path.move(to: p(x, y))
        case let .line(x, y): path.line(to: p(x, y))
        case let .curve(x, y, c1x, c1y, c2x, c2y):
            path.curve(to: p(x, y), controlPoint1: p(c1x, c1y), controlPoint2: p(c2x, c2y))
        }
    }
    path.close()
    return path
}

func renderPNG(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let canvas = NSRect(x: 0, y: 0, width: pixels, height: pixels)

    let radius = CGFloat(pixels) * 0.2237
    let background = NSBezierPath(roundedRect: canvas, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(
        starting: NSColor(srgbRed: 0.04, green: 0.50, blue: 1.0, alpha: 1),
        ending: NSColor(srgbRed: 0.35, green: 0.34, blue: 0.84, alpha: 1))!
    gradient.draw(in: background, angle: -90)

    let glyph = canvas.insetBy(dx: CGFloat(pixels) * 0.2, dy: CGFloat(pixels) * 0.2)
    NSColor.white.setFill()
    shuttlePath(in: glyph).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in variants {
    let data = renderPNG(pixels: px)
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
print("Wrote \(variants.count) PNGs to \(outDir)")
