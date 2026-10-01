//
//  SceneArt.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SpriteKit
import GameplayKit
import UIKit

// Everything in the scene is drawn in code, so there are no image files to manage.
// To use a hand-drawn rocket instead, add an image named "Rocket" to Media.xcassets.

@MainActor
enum SceneArt {
    static let spaceColor = UIColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 1)
    static let trailColor = UIColor(red: 0.35, green: 0.85, blue: 1, alpha: 0.9)
    static let guideGold = UIColor(red: 1, green: 0.82, blue: 0.45, alpha: 1)
    static let ringColors = [
        UIColor(red: 0.4, green: 0.9, blue: 1, alpha: 1),
        UIColor(red: 1, green: 0.45, blue: 0.75, alpha: 1),
        UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 1),
        UIColor(red: 0.45, green: 1, blue: 0.6, alpha: 1),
        UIColor(red: 0.7, green: 0.55, blue: 1, alpha: 1)
    ]

    /// A soft, glowing dot used for stars, glows, and particles.
    static let softDot: SKTexture = {
        let size = CGSize(width: 64, height: 64)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            let center = CGPoint(x: 32, y: 32)
            context.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: 32, options: [])
        }
        return SKTexture(image: image)
    }()

    static func glow(color: UIColor, diameter: CGFloat, alpha: CGFloat) -> SKSpriteNode {
        let glow = SKSpriteNode(texture: softDot)
        glow.color = color
        glow.colorBlendFactor = 1
        glow.alpha = alpha
        glow.size = CGSize(width: diameter, height: diameter)
        glow.blendMode = .add
        return glow
    }

    // MARK: - Rocket

    /// The rocket, about 100 points tall and pointing up.
    static func rocket() -> SKNode {
        if let drawing = UIImage(named: "Rocket") {
            let sprite = SKSpriteNode(texture: SKTexture(image: drawing))
            let aspect = drawing.size.width / max(drawing.size.height, 1)
            sprite.size = CGSize(width: 100 * aspect, height: 100)
            return sprite
        }

        let rocket = SKNode()
        let red = UIColor(red: 0.95, green: 0.3, blue: 0.3, alpha: 1)

        let leftFin = UIBezierPath()
        leftFin.move(to: CGPoint(x: -15, y: -8))
        leftFin.addLine(to: CGPoint(x: -29, y: -38))
        leftFin.addLine(to: CGPoint(x: -15, y: -30))
        leftFin.close()
        let rightFin = UIBezierPath()
        rightFin.move(to: CGPoint(x: 15, y: -8))
        rightFin.addLine(to: CGPoint(x: 29, y: -38))
        rightFin.addLine(to: CGPoint(x: 15, y: -30))
        rightFin.close()
        for fin in [leftFin, rightFin] {
            let node = SKShapeNode(path: fin.cgPath)
            node.fillColor = red
            node.strokeColor = red.withAlphaComponent(0.6)
            rocket.addChild(node)
        }

        let nozzle = SKShapeNode(rect: CGRect(x: -9, y: -43, width: 18, height: 9), cornerRadius: 2)
        nozzle.fillColor = UIColor(white: 0.45, alpha: 1)
        nozzle.strokeColor = .clear
        rocket.addChild(nozzle)

        let body = SKShapeNode(path: UIBezierPath(roundedRect: CGRect(x: -15, y: -36, width: 30, height: 60), cornerRadius: 12).cgPath)
        body.fillColor = UIColor(white: 0.96, alpha: 1)
        body.strokeColor = UIColor(white: 0.75, alpha: 1)
        body.lineWidth = 1.5
        rocket.addChild(body)

        let nose = UIBezierPath()
        nose.move(to: CGPoint(x: -15, y: 18))
        nose.addQuadCurve(to: CGPoint(x: 0, y: 50), controlPoint: CGPoint(x: -15, y: 40))
        nose.addQuadCurve(to: CGPoint(x: 15, y: 18), controlPoint: CGPoint(x: 15, y: 40))
        nose.close()
        let noseNode = SKShapeNode(path: nose.cgPath)
        noseNode.fillColor = red
        noseNode.strokeColor = .clear
        rocket.addChild(noseNode)

        let window = SKShapeNode(circleOfRadius: 7)
        window.position = CGPoint(x: 0, y: 4)
        window.fillColor = UIColor(red: 0.45, green: 0.8, blue: 1, alpha: 1)
        window.strokeColor = UIColor(white: 0.75, alpha: 1)
        window.lineWidth = 2
        rocket.addChild(window)

        return rocket
    }

    /// The rocket's flame. Its birth rate is set by RocketNode depending on thrust.
    static func exhaust() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = softDot
        emitter.particleBirthRate = 0
        emitter.particleLifetime = 0.28
        emitter.particleLifetimeRange = 0.12
        emitter.particleSpeed = 160
        emitter.particleSpeedRange = 50
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = 0.35
        emitter.particleScale = 0.45
        emitter.particleScaleRange = 0.15
        emitter.particleScaleSpeed = -1.2
        emitter.particleAlphaSpeed = -2.5
        emitter.particleColorBlendFactor = 1
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [UIColor.white, UIColor.yellow, UIColor.orange, UIColor.red],
            times: [0, 0.15, 0.5, 1]
        )
        emitter.particleBlendMode = .add
        return emitter
    }

    /// A one-shot burst of particles that removes itself afterwards.
    static func burst(colors: [UIColor], count: Int, speed: CGFloat, lifetime: CGFloat, size: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = softDot
        emitter.particleBirthRate = CGFloat(count) * 20
        emitter.numParticlesToEmit = count
        emitter.particleLifetime = lifetime
        emitter.particleLifetimeRange = lifetime * 0.5
        emitter.particleSpeed = speed
        emitter.particleSpeedRange = speed * 0.6
        emitter.emissionAngleRange = .pi * 2
        emitter.particleScale = size / 64
        emitter.particleScaleRange = size / 128
        emitter.particleScaleSpeed = -size / 128
        emitter.particleAlphaSpeed = -1 / lifetime
        emitter.particleColorBlendFactor = 1
        let times = colors.indices.map { NSNumber(value: Double($0) / Double(max(colors.count - 1, 1))) }
        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: colors, times: times)
        emitter.particleBlendMode = .add
        emitter.run(.sequence([.wait(forDuration: Double(lifetime) * 2 + 0.5), .removeFromParent()]))
        return emitter
    }

    // MARK: - Mission objects

    static func launchPad(cellSize: CGFloat) -> SKNode {
        let pad = SKNode()
        let platform = SKShapeNode(rect: CGRect(x: -cellSize * 0.4, y: -cellSize * 0.42, width: cellSize * 0.8, height: cellSize * 0.08), cornerRadius: 2)
        platform.fillColor = UIColor(white: 0.55, alpha: 1)
        platform.strokeColor = .clear
        pad.addChild(platform)

        let tower = SKShapeNode(rect: CGRect(x: cellSize * 0.28, y: -cellSize * 0.42, width: cellSize * 0.06, height: cellSize * 0.75))
        tower.fillColor = UIColor(white: 0.45, alpha: 1)
        tower.strokeColor = .clear
        pad.addChild(tower)

        let light = glow(color: .red, diameter: cellSize * 0.2, alpha: 0.9)
        light.position = CGPoint(x: cellSize * 0.31, y: cellSize * 0.33)
        light.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.6), .fadeAlpha(to: 0.9, duration: 0.6)])))
        pad.addChild(light)
        return pad
    }

    static func station(cellSize: CGFloat, animated: Bool) -> SKNode {
        let station = SKNode()

        let target = SKShapeNode(circleOfRadius: cellSize * 0.46)
        target.path = target.path?.copy(dashingWithPhase: 0, lengths: [5, 5])
        target.strokeColor = UIColor(red: 0.45, green: 1, blue: 0.6, alpha: 0.6)
        target.lineWidth = 1.5
        if animated { target.run(.repeatForever(.rotate(byAngle: .pi, duration: 6))) }
        station.addChild(target)

        for side: CGFloat in [-1, 1] {
            let panel = SKShapeNode(rect: CGRect(x: side < 0 ? -cellSize * 0.44 : cellSize * 0.16, y: -cellSize * 0.08, width: cellSize * 0.28, height: cellSize * 0.16), cornerRadius: 1)
            panel.fillColor = UIColor(red: 0.2, green: 0.4, blue: 0.85, alpha: 1)
            panel.strokeColor = UIColor(red: 0.5, green: 0.7, blue: 1, alpha: 1)
            panel.lineWidth = 1
            station.addChild(panel)
        }
        let core = SKShapeNode(rect: CGRect(x: -cellSize * 0.16, y: -cellSize * 0.12, width: cellSize * 0.32, height: cellSize * 0.24), cornerRadius: 4)
        core.fillColor = UIColor(white: 0.9, alpha: 1)
        core.strokeColor = UIColor(white: 0.6, alpha: 1)
        station.addChild(core)

        let beacon = glow(color: UIColor(red: 0.45, green: 1, blue: 0.6, alpha: 1), diameter: cellSize * 0.3, alpha: 1)
        beacon.position = CGPoint(x: 0, y: cellSize * 0.16)
        if animated { beacon.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.8), .fadeAlpha(to: 1, duration: 0.8)]))) }
        station.addChild(beacon)
        return station
    }

    /// A lumpy rock. The seed keeps each asteroid's shape the same every time it's drawn.
    static func asteroid(cellSize: CGFloat, seed: UInt64, animated: Bool) -> SKNode {
        let random = GKMersenneTwisterRandomSource(seed: seed)
        let radius = cellSize * 0.34
        let path = UIBezierPath()
        let corners = 9
        for index in 0..<corners {
            let angle = CGFloat(index) / CGFloat(corners) * .pi * 2
            let distance = radius * CGFloat(0.75 + 0.25 * random.nextUniform())
            let point = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.close()

        let rock = SKShapeNode(path: path.cgPath)
        rock.fillColor = UIColor(red: 0.42, green: 0.38, blue: 0.36, alpha: 1)
        rock.strokeColor = UIColor(red: 0.6, green: 0.55, blue: 0.5, alpha: 1)
        rock.lineWidth = 1.5
        for _ in 0..<2 {
            let crater = SKShapeNode(circleOfRadius: radius * CGFloat(0.12 + 0.1 * random.nextUniform()))
            crater.position = CGPoint(x: radius * CGFloat(random.nextUniform() - 0.5), y: radius * CGFloat(random.nextUniform() - 0.5))
            crater.fillColor = UIColor(red: 0.32, green: 0.29, blue: 0.28, alpha: 1)
            crater.strokeColor = .clear
            rock.addChild(crater)
        }
        if animated {
            let spin = random.nextBool() ? CGFloat.pi : -.pi
            rock.run(.repeatForever(.rotate(byAngle: spin, duration: Double(8 + random.nextInt(upperBound: 8)))))
        }
        return rock
    }

    /// A small Earth that sits where 4 squares meet, with clouds of land drifting across it.
    static func planet(cellSize: CGFloat, animated: Bool) -> SKNode {
        let radius = cellSize * 0.36
        let planet = SKNode()

        let orbitGuide = SKShapeNode(circleOfRadius: cellSize * 0.71)
        orbitGuide.path = orbitGuide.path?.copy(dashingWithPhase: 0, lengths: [4, 6])
        orbitGuide.strokeColor = UIColor(white: 1, alpha: 0.22)
        orbitGuide.lineWidth = 1
        planet.addChild(orbitGuide)

        planet.addChild(glow(color: UIColor(red: 0.3, green: 0.7, blue: 1, alpha: 1), diameter: radius * 5, alpha: 0.5))

        let ocean = SKShapeNode(circleOfRadius: radius)
        ocean.fillColor = UIColor(red: 0.12, green: 0.38, blue: 0.85, alpha: 1)
        ocean.strokeColor = UIColor(red: 0.5, green: 0.85, blue: 1, alpha: 0.8)
        ocean.lineWidth = 1.5
        planet.addChild(ocean)

        let mask = SKShapeNode(circleOfRadius: radius)
        mask.fillColor = .white
        let crop = SKCropNode()
        crop.maskNode = mask
        let land = SKNode()
        for (x, y, width) in [(-0.3, 0.3, 0.7), (0.4, -0.2, 0.6), (-0.1, -0.55, 0.5)] as [(CGFloat, CGFloat, CGFloat)] {
            let continent = SKShapeNode(ellipseOf: CGSize(width: radius * width * 2, height: radius * 0.45))
            continent.position = CGPoint(x: radius * x, y: radius * y)
            continent.fillColor = UIColor(red: 0.3, green: 0.75, blue: 0.4, alpha: 0.9)
            continent.strokeColor = .clear
            land.addChild(continent)
        }
        crop.addChild(land)
        if animated { land.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 30))) }
        planet.addChild(crop)
        return planet
    }

    static func moon(radius: CGFloat) -> SKNode {
        let moon = SKNode()
        moon.addChild(glow(color: .white, diameter: radius * 2.6, alpha: 0.22))
        let surface = SKShapeNode(circleOfRadius: radius)
        surface.fillColor = UIColor(white: 0.78, alpha: 1)
        surface.strokeColor = UIColor(white: 1, alpha: 0.5)
        surface.lineWidth = 2
        moon.addChild(surface)

        let random = GKMersenneTwisterRandomSource(seed: 1969)
        for _ in 0..<9 {
            // Craters sit in the lower half, the part that's visible on screen.
            let angle = CGFloat.pi + CGFloat(random.nextUniform()) * .pi
            let distance = radius * CGFloat(0.25 + 0.65 * random.nextUniform())
            let crater = SKShapeNode(circleOfRadius: radius * CGFloat(0.04 + 0.08 * random.nextUniform()))
            crater.position = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            crater.fillColor = UIColor(white: 0.64, alpha: 1)
            crater.strokeColor = UIColor(white: 0.58, alpha: 1)
            surface.addChild(crater)
        }
        return moon
    }
}
