import AppKit
import SwiftUI

/// Eine einzige Quelle der Wahrheit für die Shuttle-Silhouette.
/// Entwurfsraum ist 100×100, y zeigt nach unten (Nase oben).
enum ShuttleGeometry {
    enum Segment {
        case move(CGFloat, CGFloat)
        case line(CGFloat, CGFloat)
        /// Ziel + zwei Kontrollpunkte (kubische Bézier-Kurve).
        case curve(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
    }

    // Seitenansicht des Orbiters, Nase nach rechts, im Quadrat zentriert.
    static let segments: [Segment] = [
        .move(95, 54),                    // Nasenspitze
        .curve(76, 45, 93, 48, 86, 45),   // gerundete Nase hoch zum Cockpit
        .line(38, 42),                    // Rumpfoberkante nach hinten
        .line(24, 18),                    // Vorderkante Heckflosse zur Spitze
        .line(16, 43),                    // Hinterkante Heckflosse zum Rumpf
        .line(8, 49),                     // Heck oben
        .line(8, 60),                     // stumpfes Heck (Triebwerke)
        .line(28, 62),                    // Bauch bis Flügelansatz
        .line(33, 82),                    // Deltaflügel-Spitze (unten hinten)
        .line(58, 62),                    // Flügelvorderkante zurück zum Bauch
        .line(84, 60),                    // Bauch nach vorne
        .curve(95, 54, 90, 59, 95, 57),   // gerundete Nase unten zur Spitze
    ]

    private static func map(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + x / 100 * rect.width,
                y: rect.minY + y / 100 * rect.height)
    }

    /// Baut die Silhouette in eine SwiftUI-Path (für den Header).
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

    /// Baut die Silhouette in eine NSBezierPath (für das Menüleisten-Icon).
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

/// SwiftUI-Form für die Verwendung im Dropdown-Header.
struct ShuttleShape: Shape {
    func path(in rect: CGRect) -> Path {
        ShuttleGeometry.swiftUIPath(in: rect)
    }
}

/// Das Menüleisten-Icon als Template-NSImage (passt sich hell/dunkel an).
enum MenuBarIcon {
    static let image: NSImage = {
        // flipped: true → Ursprung oben links, passend zum Entwurfsraum (y nach unten).
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
