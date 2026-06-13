import AppKit
import SwiftUI

/// A single source of truth for the shuttle silhouette.
/// Design space is 100×100, y points down (nose at top).
enum ShuttleGeometry {
    enum Segment {
        case move(CGFloat, CGFloat)
        case line(CGFloat, CGFloat)
        /// Target + two control points (cubic Bézier curve).
        case curve(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
    }

    // Side view of the orbiter, nose pointing right, centered in the square.
    static let segments: [Segment] = [
        .move(95, 54),                    // nose tip
        .curve(76, 45, 93, 48, 86, 45),   // rounded nose up to the cockpit
        .line(38, 42),                    // top of the fuselage going back
        .line(24, 18),                    // tail fin leading edge to the tip
        .line(16, 43),                    // tail fin trailing edge to the fuselage
        .line(8, 49),                     // rear top
        .line(8, 60),                     // blunt rear (engines)
        .line(28, 62),                    // belly to the wing root
        .line(33, 82),                    // delta wing tip (bottom rear)
        .line(58, 62),                    // wing leading edge back to the belly
        .line(84, 60),                    // belly going forward
        .curve(95, 54, 90, 59, 95, 57),   // rounded nose bottom to the tip
    ]

    private static func map(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + x / 100 * rect.width,
                y: rect.minY + y / 100 * rect.height)
    }

    /// Builds the silhouette into a SwiftUI Path (for the header).
    static func swiftUIPath(in rect: CGRect) -> Path {
        var path = Path()
        for segment in segments {
            switch segment {
            case let .move(x, y):
                path.move(to: map(x, y, in: rect))
            case let .line(x, y):
                path.addLine(to: map(x, y, in: rect))
            case let .curve(x, y, c1x, c1y, c2x, c2y):
                path.addCurve(to: map(x, y, in: rect),
                              control1: map(c1x, c1y, in: rect),
                              control2: map(c2x, c2y, in: rect))
            }
        }
        path.closeSubpath()
        return path
    }

    /// Builds the silhouette into an NSBezierPath (for the menu bar icon).
    static func bezierPath(in rect: CGRect) -> NSBezierPath {
        let path = NSBezierPath()
        for segment in segments {
            switch segment {
            case let .move(x, y):
                path.move(to: map(x, y, in: rect))
            case let .line(x, y):
                path.line(to: map(x, y, in: rect))
            case let .curve(x, y, c1x, c1y, c2x, c2y):
                path.curve(to: map(x, y, in: rect),
                           controlPoint1: map(c1x, c1y, in: rect),
                           controlPoint2: map(c2x, c2y, in: rect))
            }
        }
        path.close()
        return path
    }
}

/// SwiftUI shape for use in the dropdown header.
struct ShuttleShape: Shape {
    func path(in rect: CGRect) -> Path {
        ShuttleGeometry.swiftUIPath(in: rect)
    }
}

/// The menu bar icon as a template NSImage (adapts to light/dark).
enum MenuBarIcon {
    static let image: NSImage = {
        // flipped: true → origin at top left, matching the design space (y downward).
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            NSColor.black.setFill()
            ShuttleGeometry.bezierPath(in: rect).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ShuttleX"
        return image
    }()
}
