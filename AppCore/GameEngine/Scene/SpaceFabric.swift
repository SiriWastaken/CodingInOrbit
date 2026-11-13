//
//  SpaceFabric.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-10-01.
//

import SpriteKit
import simd

// A faint grid that fills the sky, like the stretchy sheet in every gravity diagram.
// Heavy things (a sun, a planet, the Moon) pull the grid toward them. When the rocket
// moves, a ripple spreads through it. That's what "move() bends space" looks like.
//
// It's one sprite with a grid texture, bent by SpriteKit's warp geometry. No physics.

@MainActor
final class SpaceFabric: SKSpriteNode {
    private let columns = 24
    private let rows = 16
    private let restingAlpha: CGFloat = 0.1

    private struct Ripple {
        var center: CGPoint
        var age: TimeInterval = 0
        var strength: CGFloat
    }

    private var ripples: [Ripple] = []
    private var masses: [(center: CGPoint, strength: CGFloat)] = []
    private var needsRefresh = true
    private var unit: CGFloat = 1
    private var isStill = false

    init() {
        super.init(texture: nil, color: .clear, size: .zero)
        alpha = restingAlpha
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(size newSize: CGSize, masses: [(center: CGPoint, strength: CGFloat)], reduceMotion: Bool, highContrast: Bool) {
        unit = min(newSize.width, newSize.height)
        isStill = reduceMotion
        self.masses = masses
        if size != newSize || texture == nil {
            texture = SceneArt.fabricTexture(size: newSize, cell: max(unit / 7, 24))
            size = newSize
            position = CGPoint(x: newSize.width / 2, y: newSize.height / 2)
        }
        removeAction(forKey: "alpha")
        alpha = highContrast ? 0.3 : restingAlpha
        needsRefresh = true
    }

    /// Sends a wave through the grid from a point.
    func ripple(at point: CGPoint, strength: CGFloat = 1) {
        guard !isStill else { return }
        ripples.append(Ripple(center: point, strength: strength))
        removeAction(forKey: "alpha")
        run(.sequence([.fadeAlpha(to: 0.34, duration: 0.12), .fadeAlpha(to: restingAlpha, duration: 1.6)]), withKey: "alpha")
    }

    func update(deltaTime: TimeInterval) {
        for index in ripples.indices { ripples[index].age += deltaTime }
        let before = ripples.count
        ripples.removeAll { $0.age > 1.8 }
        guard needsRefresh || !ripples.isEmpty || before != ripples.count else { return }
        needsRefresh = false
        applyWarp()
    }

    private func applyWarp() {
        guard size.width > 1 else { return }
        let identity = SKWarpGeometryGrid(columns: columns, rows: rows)
        var destination: [SIMD2<Float>] = []
        destination.reserveCapacity(identity.vertexCount)

        for index in 0..<identity.vertexCount {
            let source = identity.sourcePosition(at: index)
            let point = CGPoint(x: CGFloat(source.x) * size.width, y: CGFloat(source.y) * size.height)
            var shifted = point

            for mass in masses {
                let dx = mass.center.x - point.x, dy = mass.center.y - point.y
                let distance = max(hypot(dx, dy), 1)
                let reach = unit * 0.32 * mass.strength
                // Pulls grid lines toward the mass, strongest at a middle distance so lines bunch up around it.
                let pull = unit * 0.1 * mass.strength * exp(-pow(distance / reach, 2)) * min(1, distance / (unit * 0.12))
                shifted.x += dx / distance * pull
                shifted.y += dy / distance * pull
            }

            for ripple in ripples {
                let dx = point.x - ripple.center.x, dy = point.y - ripple.center.y
                let distance = max(hypot(dx, dy), 1)
                let front = CGFloat(ripple.age) * unit * 0.85
                let falloff = exp(-pow((distance - front) / (unit * 0.16), 2))
                let fade = CGFloat(max(0, 1 - ripple.age / 1.8))
                let push = sin((distance - front) / (unit * 0.05)) * unit * 0.035 * ripple.strength * falloff * fade
                shifted.x += dx / distance * push
                shifted.y += dy / distance * push
            }

            destination.append(SIMD2(Float(shifted.x / size.width), Float(shifted.y / size.height)))
        }
        warpGeometry = identity.replacingByDestinationPositions(positions: destination)
    }
}
