#!/usr/bin/env swift
import AppKit

// Builds the AppIcon .iconset from a rasterized shuttle PNG (dark silhouette on
// a light background, as QuickLook produces): turns darkness into a white,
// transparent-background silhouette, trims it, and centers it on the blue→indigo
// rounded-square. Source art: Pixabay (Content License), image 294104.
// Usage: make-app-icon.swift <source.png> <outDir.iconset>

let args = CommandLine.arguments
guard args.count == 3 else { fputs("usage: make-app-icon <source.png> <outDir>\n", stderr); exit(1) }

guard let srcImage = NSImage(contentsOf: URL(fileURLWithPath: args[1])),
      let tiff = srcImage.tiffRepresentation,
      let src = NSBitmapImageRep(data: tiff),
      let srcData = src.bitmapData else { fputs("cannot load source\n", stderr); exit(2) }

let width = src.pixelsWide, height = src.pixelsHigh
let spp = src.samplesPerPixel
let bytesPerRow = src.bytesPerRow
let alphaFirst = src.bitmapFormat.contains(.alphaFirst)

// Build a white silhouette: alpha = darkness (so the light background drops out),
// RGB = white. Track the opaque bounding box while we're at it.
guard let dest = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bitmapFormat: .alphaNonpremultiplied,
    bytesPerRow: width * 4, bitsPerPixel: 32),
    let dstData = dest.bitmapData else { fputs("cannot allocate\n", stderr); exit(3) }

var minX = width, minY = height, maxX = 0, maxY = 0
for y in 0..<height {
    let srow = srcData + y * bytesPerRow
    let drow = dstData + y * width * 4
    for x in 0..<width {
        let sp = srow + x * spp + (alphaFirst ? 1 : 0)
        let luma = (Int(sp[0]) + Int(sp[1]) + Int(sp[2])) / 3
        let srcAlpha = alphaFirst ? (srow + x * spp)[0] : (spp == 4 ? (srow + x * spp)[3] : 255)
        let alpha = UInt8(Double(255 - luma) * Double(srcAlpha) / 255.0)
        let dp = drow + x * 4
        dp[0] = 255; dp[1] = 255; dp[2] = 255; dp[3] = alpha
        if alpha > 12 {
            if x < minX { minX = x }; if x > maxX { maxX = x }
            if y < minY { minY = y }; if y > maxY { maxY = y }
        }
    }
}
guard minX <= maxX, minY <= maxY, let whiteFull = dest.cgImage else { fputs("empty image\n", stderr); exit(4) }
let bbox = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
guard let whiteCG = whiteFull.cropping(to: bbox) else { exit(5) }
let glyph = NSImage(cgImage: whiteCG, size: NSSize(width: whiteCG.width, height: whiteCG.height))

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
    NSGradient(
        starting: NSColor(srgbRed: 0.04, green: 0.50, blue: 1.0, alpha: 1),
        ending: NSColor(srgbRed: 0.35, green: 0.34, blue: 0.84, alpha: 1))!
        .draw(in: background, angle: -90)

    let maxDim = CGFloat(pixels) * 0.62
    let scale = min(maxDim / CGFloat(whiteCG.width), maxDim / CGFloat(whiteCG.height))
    let gw = CGFloat(whiteCG.width) * scale, gh = CGFloat(whiteCG.height) * scale
    glyph.draw(in: NSRect(x: (CGFloat(pixels) - gw) / 2, y: (CGFloat(pixels) - gh) / 2, width: gw, height: gh))

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
    try! renderPNG(pixels: px).write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
print("Wrote \(variants.count) PNGs to \(outDir)")
