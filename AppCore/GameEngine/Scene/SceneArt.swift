//
//  SceneArt.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SpriteKit
import SwiftUI
import GameplayKit
import UIKit

// Everything in the scene is drawn in code, using only the app's six palette colors
// (and blends of them). To use a hand-drawn rocket instead, add an image named "Rocket"
// to Media.xcassets.

@MainActor
enum SceneArt {
    // Scene colors, all mixed from the palette.
    static let trailColor = Palette.nebulaBlue
    static let ringColors = [Palette.nebulaBlue, Palette.goldTrim, Palette.ember, Palette.starlight]
    static let stone = Palette.dusk.mixed(with: Palette.ember, 0.28).mixed(with: Palette.starlight, 0.12)
    static let ocean = Palette.nebulaBlue.mixed(with: Palette.deepSpace, 0.35)
    static let sand = Palette.goldTrim.mixed(with: Palette.starlight, 0.25)
    static let moonDust = Palette.starlight.mixed(with: Palette.dusk, 0.22)

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

    /// A four-pointed sparkle (the same shape as the app's SparkleShape), for star bursts.
    static let sparkle: SKTexture = {
        let size = CGSize(width: 64, height: 64)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.white.setFill()
            UIBezierPath(cgPath: SparkleShape().path(in: CGRect(origin: .zero, size: size)).cgPath).fill()
        }
        return SKTexture(image: image)
    }()

    /// Text drawn with SF Mono into a sprite, so the scene uses the app's typeface.
    static func label(_ text: String, size: CGFloat, color: UIColor) -> SKSpriteNode {
        let font = UIFont.monospacedSystemFont(ofSize: size, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let image = UIGraphicsImageRenderer(size: textSize).image { _ in
            (text as NSString).draw(at: .zero, withAttributes: attributes)
        }
        let sprite = SKSpriteNode(texture: SKTexture(image: image))
        sprite.size = textSize
        return sprite
    }

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
        let paint = Palette.ember

        // The fins are a little uneven, like they were cut out by hand.
        let leftFin = UIBezierPath()
        leftFin.move(to: CGPoint(x: -15, y: -8))
        leftFin.addQuadCurve(to: CGPoint(x: -30, y: -38), controlPoint: CGPoint(x: -27, y: -18))
        leftFin.addLine(to: CGPoint(x: -15, y: -30))
        leftFin.close()
        let rightFin = UIBezierPath()
        rightFin.move(to: CGPoint(x: 15, y: -9))
        rightFin.addQuadCurve(to: CGPoint(x: 28, y: -37), controlPoint: CGPoint(x: 26, y: -19))
        rightFin.addLine(to: CGPoint(x: 15, y: -31))
        rightFin.close()
        for fin in [leftFin, rightFin] {
            let node = SKShapeNode(path: fin.cgPath)
            node.fillColor = paint
            node.strokeColor = paint.mixed(with: Palette.deepSpace, 0.3)
            node.lineWidth = 1.5
            rocket.addChild(node)
        }

        let nozzle = SKShapeNode(rect: CGRect(x: -9, y: -43, width: 18, height: 9), cornerRadius: 2)
        nozzle.fillColor = Palette.dusk.mixed(with: Palette.starlight, 0.3)
        nozzle.strokeColor = .clear
        rocket.addChild(nozzle)

        let body = SKShapeNode(path: UIBezierPath(roundedRect: CGRect(x: -15, y: -36, width: 30, height: 60), cornerRadius: 13).cgPath)
        body.fillColor = Palette.starlight
        body.strokeColor = Palette.starlight.mixed(with: Palette.dusk, 0.35)
        body.lineWidth = 1.5
        rocket.addChild(body)

        let nose = UIBezierPath()
        nose.move(to: CGPoint(x: -15, y: 18))
        nose.addQuadCurve(to: CGPoint(x: 1, y: 50), controlPoint: CGPoint(x: -15, y: 41))
        nose.addQuadCurve(to: CGPoint(x: 15, y: 18), controlPoint: CGPoint(x: 15, y: 39))
        nose.close()
        let noseNode = SKShapeNode(path: nose.cgPath)
        noseNode.fillColor = paint
        noseNode.strokeColor = .clear
        rocket.addChild(noseNode)

        let window = SKShapeNode(circleOfRadius: 7)
        window.name = "window"
        window.position = CGPoint(x: 0, y: 4)
        window.fillColor = Palette.nebulaBlue
        window.strokeColor = Palette.starlight.mixed(with: Palette.dusk, 0.35)
        window.lineWidth = 2
        rocket.addChild(window)

        // A tiny glint on the window, so the rocket looks back at you.
        let glint = SKShapeNode(circleOfRadius: 2)
        glint.position = CGPoint(x: -2.5, y: 6.5)
        glint.fillColor = Palette.starlight
        glint.strokeColor = .clear
        window.addChild(glint)

        return rocket
    }

    /// A little astronaut helmet bubble that appears over the window in astronaut mode.
    static func helmet() -> SKNode {
        let helmet = SKNode()
        let bubble = SKShapeNode(circleOfRadius: 13)
        bubble.position = CGPoint(x: 0, y: 4)
        bubble.fillColor = Palette.starlight.withAlphaComponent(0.18)
        bubble.strokeColor = Palette.goldTrim
        bubble.lineWidth = 2.5
        helmet.addChild(bubble)
        let shine = SKShapeNode(path: UIBezierPath(arcCenter: CGPoint(x: 0, y: 4), radius: 9, startAngle: .pi * 0.6, endAngle: .pi * 0.95, clockwise: true).cgPath)
        shine.strokeColor = Palette.starlight
        shine.lineWidth = 2
        shine.lineCap = .round
        helmet.addChild(shine)
        let antenna = SKShapeNode(path: {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 6, y: 16))
            path.addQuadCurve(to: CGPoint(x: 12, y: 28), control: CGPoint(x: 13, y: 20))
            return path
        }())
        antenna.strokeColor = Palette.goldTrim
        antenna.lineWidth = 2
        antenna.lineCap = .round
        helmet.addChild(antenna)
        let tip = glow(color: Palette.goldTrim, diameter: 10, alpha: 1)
        tip.position = CGPoint(x: 12, y: 28)
        tip.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
        helmet.addChild(tip)
        return helmet
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
            keyframeValues: [Palette.starlight, Palette.goldTrim, Palette.ember, Palette.ember.withAlphaComponent(0)],
            times: [0, 0.2, 0.6, 1]
        )
        emitter.particleBlendMode = .add
        return emitter
    }

    /// A one-shot burst of particles that removes itself afterwards.
    static func burst(colors: [UIColor], count: Int, speed: CGFloat, lifetime: CGFloat, size: CGFloat, texture: SKTexture? = nil) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = texture ?? softDot
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
        emitter.particleRotationRange = .pi
        emitter.particleRotationSpeed = texture == nil ? 0 : 1.5
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
        let metal = Palette.dusk.mixed(with: Palette.starlight, 0.35)
        let platform = SKShapeNode(rect: CGRect(x: -cellSize * 0.4, y: -cellSize * 0.42, width: cellSize * 0.8, height: cellSize * 0.08), cornerRadius: 2)
        platform.fillColor = metal
        platform.strokeColor = .clear
        pad.addChild(platform)

        let tower = SKShapeNode(rect: CGRect(x: cellSize * 0.28, y: -cellSize * 0.42, width: cellSize * 0.06, height: cellSize * 0.75))
        tower.fillColor = metal.mixed(with: Palette.deepSpace, 0.2)
        tower.strokeColor = .clear
        pad.addChild(tower)

        let light = glow(color: Palette.ember, diameter: cellSize * 0.2, alpha: 0.9)
        light.position = CGPoint(x: cellSize * 0.31, y: cellSize * 0.33)
        light.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.6), .fadeAlpha(to: 0.9, duration: 0.6)])))
        pad.addChild(light)
        return pad
    }

    static func station(cellSize: CGFloat, animated: Bool) -> SKNode {
        let station = SKNode()

        let target = SKShapeNode(circleOfRadius: cellSize * 0.46)
        target.path = target.path?.copy(dashingWithPhase: 0, lengths: [5, 5])
        target.strokeColor = Palette.goldTrim.withAlphaComponent(0.6)
        target.lineWidth = 1.5
        if animated { target.run(.repeatForever(.rotate(byAngle: .pi, duration: 6))) }
        station.addChild(target)

        for side: CGFloat in [-1, 1] {
            let panel = SKShapeNode(rect: CGRect(x: side < 0 ? -cellSize * 0.44 : cellSize * 0.16, y: -cellSize * 0.08, width: cellSize * 0.28, height: cellSize * 0.16), cornerRadius: 1)
            panel.fillColor = Palette.nebulaBlue.mixed(with: Palette.dusk, 0.35)
            panel.strokeColor = Palette.nebulaBlue
            panel.lineWidth = 1
            station.addChild(panel)
        }
        let core = SKShapeNode(rect: CGRect(x: -cellSize * 0.16, y: -cellSize * 0.12, width: cellSize * 0.32, height: cellSize * 0.24), cornerRadius: 4)
        core.fillColor = Palette.starlight
        core.strokeColor = Palette.starlight.mixed(with: Palette.dusk, 0.35)
        station.addChild(core)

        let beacon = glow(color: Palette.goldTrim, diameter: cellSize * 0.3, alpha: 1)
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
        rock.fillColor = stone
        rock.strokeColor = stone.mixed(with: Palette.starlight, 0.25)
        rock.lineWidth = 1.5
        rock.lineJoin = .round
        for _ in 0..<2 {
            let crater = SKShapeNode(circleOfRadius: radius * CGFloat(0.12 + 0.1 * random.nextUniform()))
            crater.position = CGPoint(x: radius * CGFloat(random.nextUniform() - 0.5), y: radius * CGFloat(random.nextUniform() - 0.5))
            crater.fillColor = stone.mixed(with: Palette.deepSpace, 0.3)
            crater.strokeColor = .clear
            rock.addChild(crater)
        }
        if animated {
            let spin = random.nextBool() ? CGFloat.pi : -.pi
            rock.run(.repeatForever(.rotate(byAngle: spin, duration: Double(8 + random.nextInt(upperBound: 8)))))
        }
        return rock
    }

    /// A small Earth that sits where 4 squares meet, with continents drifting across it.
    static func planet(cellSize: CGFloat, animated: Bool) -> SKNode {
        let radius = cellSize * 0.36
        let planet = SKNode()

        let orbitGuide = SKShapeNode(circleOfRadius: cellSize * 0.71)
        orbitGuide.path = orbitGuide.path?.copy(dashingWithPhase: 0, lengths: [4, 6])
        orbitGuide.strokeColor = Palette.starlight.withAlphaComponent(0.22)
        orbitGuide.lineWidth = 1
        planet.addChild(orbitGuide)

        planet.addChild(glow(color: Palette.nebulaBlue, diameter: radius * 5, alpha: 0.5))

        let water = SKShapeNode(circleOfRadius: radius)
        water.fillColor = ocean
        water.strokeColor = Palette.nebulaBlue
        water.lineWidth = 1.5
        planet.addChild(water)

        let mask = SKShapeNode(circleOfRadius: radius)
        mask.fillColor = .white
        let crop = SKCropNode()
        crop.maskNode = mask
        let land = SKNode()
        for (x, y, width) in [(-0.3, 0.3, 0.7), (0.4, -0.2, 0.6), (-0.1, -0.55, 0.5)] as [(CGFloat, CGFloat, CGFloat)] {
            let continent = SKShapeNode(ellipseOf: CGSize(width: radius * width * 2, height: radius * 0.45))
            continent.position = CGPoint(x: radius * x, y: radius * y)
            continent.fillColor = sand
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
        moon.addChild(glow(color: Palette.goldTrim, diameter: radius * 2.6, alpha: 0.18))
        let surface = SKShapeNode(circleOfRadius: radius)
        surface.fillColor = moonDust
        surface.strokeColor = Palette.starlight.withAlphaComponent(0.6)
        surface.lineWidth = 2
        moon.addChild(surface)

        let random = GKMersenneTwisterRandomSource(seed: 1969)
        for _ in 0..<9 {
            // Craters sit in the lower half, the part that's visible on screen.
            let angle = CGFloat.pi + CGFloat(random.nextUniform()) * .pi
            let distance = radius * CGFloat(0.25 + 0.65 * random.nextUniform())
            let crater = SKShapeNode(circleOfRadius: radius * CGFloat(0.04 + 0.08 * random.nextUniform()))
            crater.position = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            crater.fillColor = moonDust.mixed(with: Palette.dusk, 0.18)
            crater.strokeColor = moonDust.mixed(with: Palette.dusk, 0.28)
            surface.addChild(crater)
        }
        return moon
    }
}
