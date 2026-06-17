#!/usr/bin/env swift
import AppKit

// Builds the GitHub social-preview image (1280×640): the app icon on a blue→indigo
// field next to the ShuttleX wordmark and tagline.
// Usage: make-social-preview.swift <icon.png> <out.png>

let args = CommandLine.arguments
guard args.count == 3, let icon = NSImage(contentsOfFile: args[1]) else {
    fputs("usage: make-social-preview <icon.png> <out.png>\n", stderr); exit(1)
}

let W = 1280, H = 640
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let canvas = NSRect(x: 0, y: 0, width: W, height: H)

NSGradient(
    starting: NSColor(srgbRed: 0.05, green: 0.42, blue: 0.98, alpha: 1),
    ending: NSColor(srgbRed: 0.33, green: 0.32, blue: 0.83, alpha: 1))!
    .draw(in: canvas, angle: -45)

let iconSize: CGFloat = 380
icon.draw(in: NSRect(x: 120, y: (CGFloat(H) - iconSize) / 2, width: iconSize, height: iconSize))

let title = NSAttributedString(string: "ShuttleX", attributes: [
    .font: NSFont.systemFont(ofSize: 118, weight: .bold),
    .foregroundColor: NSColor.white,
])
title.draw(at: NSPoint(x: 590, y: 320))

let tagline = NSAttributedString(string: "SSH launcher for the\nmacOS menu bar", attributes: [
    .font: NSFont.systemFont(ofSize: 40, weight: .medium),
    .foregroundColor: NSColor.white.withAlphaComponent(0.9),
])
tagline.draw(in: NSRect(x: 594, y: 150, width: 580, height: 150))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("Wrote \(args[2])")
