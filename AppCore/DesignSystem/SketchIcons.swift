//
//  SketchIcons.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI

// Little drawings for the places where an icon should feel hand-made. Each one is a bit
// uneven on purpose: arms of different lengths, rings that don't quite close.

/// A four-pointed sparkle with slightly uneven arms.
struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let arms: [CGFloat] = [1, 0.9, 0.98, 0.86]
        let waist = radius * 0.26
        var path = Path()
        for index in 0..<4 {
            let angle = CGFloat(index) * .pi / 2 - .pi / 2
            let tip = CGPoint(x: center.x + cos(angle) * radius * arms[index], y: center.y + sin(angle) * radius * arms[index])
            let between = angle + .pi / 4
            let notch = CGPoint(x: center.x + cos(between) * waist, y: center.y + sin(between) * waist)
            if index == 0 { path.move(to: tip) } else { path.addLine(to: tip) }
            path.addQuadCurve(to: notch, control: CGPoint(x: center.x + cos(angle + .pi / 8) * waist * 1.2, y: center.y + sin(angle + .pi / 8) * waist * 1.2))
        }
        path.closeSubpath()
        return path
    }
}

/// A crescent moon, a little lopsided.
struct CrescentShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 1.96))
        path.addEllipse(in: CGRect(x: center.x - radius * 0.45, y: center.y - radius * 1.08, width: radius * 1.8, height: radius * 1.8))
        // Fill with an even-odd rule so the second circle cuts the crescent out of the first.
        return path
    }
}

/// A small rocket outline, drawn the way you'd doodle one in a notebook margin.
struct RocketGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * w, y: rect.minY + y * h) }
        var path = Path()
        // Body and nose
        path.move(to: p(0.36, 0.78))
        path.addLine(to: p(0.35, 0.42))
        path.addQuadCurve(to: p(0.5, 0.04), control: p(0.36, 0.14))
        path.addQuadCurve(to: p(0.65, 0.43), control: p(0.65, 0.15))
        path.addLine(to: p(0.64, 0.78))
        path.closeSubpath()
        // Fins
        path.move(to: p(0.35, 0.56))
        path.addLine(to: p(0.17, 0.86))
        path.addLine(to: p(0.36, 0.76))
        path.move(to: p(0.65, 0.57))
        path.addLine(to: p(0.84, 0.85))
        path.addLine(to: p(0.64, 0.77))
        // Window
        path.addEllipse(in: CGRect(x: rect.minX + 0.42 * w, y: rect.minY + 0.33 * h, width: 0.16 * w, height: 0.15 * h))
        // A wobbly little flame
        path.move(to: p(0.43, 0.82))
        path.addQuadCurve(to: p(0.5, 0.98), control: p(0.42, 0.92))
        path.addQuadCurve(to: p(0.58, 0.82), control: p(0.6, 0.9))
        return path
    }
}

/// A planet with a tilted ring that doesn't quite close, like a quick sketch.
struct OrbitGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let size = min(rect.width, rect.height)
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - size * 0.22, y: center.y - size * 0.22, width: size * 0.44, height: size * 0.43))
        var ring = Path()
        ring.addArc(center: .zero, radius: size * 0.46, startAngle: .degrees(-160), endAngle: .degrees(170), clockwise: false)
        let squash = CGAffineTransform(scaleX: 1, y: 0.38).rotated(by: -.pi / 9).concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        path.addPath(ring, transform: squash)
        return path
    }
}

/// Picks the hand-drawn icon for each mission.
struct MissionGlyph: View {
    let mission: MissionID

    var body: some View {
        switch mission {
        case .liftoff:
            RocketGlyph().stroke(Color.starlight, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        case .lowEarthOrbit:
            OrbitGlyph().stroke(Color.starlight, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        case .toTheMoon:
            CrescentShape().fill(Color.starlight, style: FillStyle(eoFill: true))
        }
    }
}
