#!/usr/bin/env swift
import AppKit

// Renders a BETA-badged variant of the stable app icon at all iconset sizes:
// the existing icon with an orange "BETA" band across the bottom (clipped to the
// rounded-square so it follows the corners). Used for prerelease builds so Beta
// and Stable are distinguishable in Finder / the Applications folder.
// Usage: make-beta-icon.swift <AppIcon.icns> <outDir.iconset>

let args = CommandLine.arguments
guard args.count == 3 else { fputs("usage: make-beta-icon <in.icns> <outDir.iconset>\n", stderr); exit(1) }
guard let base = NSImage(contentsOfFile: args[1]) else { fputs("cannot load \(args[1])\n", stderr); exit(2) }

func badged(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let canvas = NSRect(x: 0, y: 0, width: pixels, height: pixels)

    base.draw(in: canvas)

    // Clip everything below to the rounded-square so the band follows the corners.
    let radius = CGFloat(pixels) * 0.2237
    NSBezierPath(roundedRect: canvas, xRadius: radius, yRadius: radius).addClip()

    let bandHeight = CGFloat(pixels) * 0.26
    let band = NSRect(x: 0, y: 0, width: CGFloat(pixels), height: bandHeight)
    NSColor(srgbRed: 1.0, green: 0.42, blue: 0.0, alpha: 0.96).setFill()
    band.fill()

    let text = "BETA" as NSString
    let fontSize = bandHeight * 0.56
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
        .foregroundColor: NSColor.white,
        .paragraphStyle: para,
        .kern: fontSize * 0.12,
    ]
    let textSize = text.size(withAttributes: attrs)
    let rect = NSRect(x: 0, y: (bandHeight - textSize.height) / 2, width: CGFloat(pixels), height: textSize.height)
    text.draw(in: rect, withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outDir = args[2]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let variants: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in variants {
    try! badged(pixels: px).write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
print("Wrote \(variants.count) badged PNGs to \(outDir)")
