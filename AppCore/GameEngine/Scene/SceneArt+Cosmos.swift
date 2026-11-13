//
//  SceneArt+Cosmos.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-10-01.
//

import SpriteKit
import GameplayKit
import UIKit

// The things code can create. Like the rest of SceneArt, every one is drawn in code from the
// six palette colors and blends of them, so the whole app stays tiny and consistent.
// Each factory takes the size it should appear on screen.

extension SceneArt {
    // MARK: - Spheres

    /// A lit ball with details painted on its surface and a soft shadow on the far side.
    /// The surface node is returned so continents or bands can drift across it.
    private static func sphere(radius: CGFloat, fill: UIColor, edge: UIColor,
                               paint: (SKNode) -> Void) -> (node: SKNode, surface: SKNode) {
        let node = SKNode()
        let body = SKShapeNode(circleOfRadius: radius)
        body.fillColor = fill
        body.strokeColor = edge
        body.lineWidth = max(1.2, radius * 0.05)
        node.addChild(body)

        let mask = SKShapeNode(circleOfRadius: radius)
        mask.fillColor = .white
        mask.strokeColor = .clear
        let crop = SKCropNode()
        crop.maskNode = mask
        let surface = SKNode()
        paint(surface)
        crop.addChild(surface)

        let shade = SKShapeNode(circleOfRadius: radius * 1.05)
        shade.position = CGPoint(x: radius * 0.55, y: -radius * 0.5)
        shade.fillColor = Palette.deepSpace.withAlphaComponent(0.4)
        shade.strokeColor = .clear
        crop.addChild(shade)
        node.addChild(crop)
        return (node, surface)
    }

    private static func patch(_ size: CGSize, at point: CGPoint, color: UIColor) -> SKShapeNode {
        let patch = SKShapeNode(ellipseOf: size)
        patch.position = point
        patch.fillColor = color
        patch.strokeColor = .clear
        return patch
    }

    /// Four kinds of planet, by the order they're made: Earth, Mars, Saturn, Neptune.
    static func planet(radius: CGFloat, style: Int, animated: Bool) -> SKNode {
        let planet = SKNode()
        let glowColor = [Palette.nebulaBlue, Palette.ember, Palette.goldTrim, Palette.nebulaBlue][style % 4]
        planet.addChild(glow(color: glowColor, diameter: radius * 4.4, alpha: 0.38))

        switch style % 4 {
        case 0:
            let earth = sphere(radius: radius, fill: ocean, edge: Palette.nebulaBlue) { surface in
                for (x, y, width) in [(-0.3, 0.3, 0.7), (0.4, -0.2, 0.6), (-0.1, -0.55, 0.5)] as [(CGFloat, CGFloat, CGFloat)] {
                    surface.addChild(patch(CGSize(width: radius * width * 2, height: radius * 0.45),
                                           at: CGPoint(x: radius * x, y: radius * y), color: sand))
                }
            }
            if animated { earth.surface.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 40))) }
            planet.addChild(earth.node)
        case 1:
            let mars = sphere(radius: radius, fill: Palette.ember.mixed(with: Palette.dusk, 0.3), edge: Palette.ember) { surface in
                for (x, y, width) in [(-0.35, 0.15, 0.5), (0.3, -0.3, 0.6), (0.1, 0.5, 0.35)] as [(CGFloat, CGFloat, CGFloat)] {
                    surface.addChild(patch(CGSize(width: radius * width * 2, height: radius * 0.35),
                                           at: CGPoint(x: radius * x, y: radius * y), color: Palette.ember.mixed(with: Palette.dusk, 0.6)))
                }
                surface.addChild(patch(CGSize(width: radius * 0.7, height: radius * 0.22),
                                       at: CGPoint(x: 0, y: radius * 0.9), color: Palette.starlight.withAlphaComponent(0.85)))
            }
            planet.addChild(mars.node)
        case 2:
            let tilt: CGFloat = -0.35
            let ringSize = CGSize(width: radius * 3.3, height: radius * 0.9)
            let back = SKShapeNode(ellipseOf: ringSize)
            back.strokeColor = Palette.starlight.withAlphaComponent(0.55)
            back.lineWidth = max(2, radius * 0.16)
            back.zRotation = tilt
            planet.addChild(back)

            let saturn = sphere(radius: radius, fill: Palette.goldTrim.mixed(with: sand, 0.4), edge: Palette.goldTrim) { surface in
                for (y, height) in [(0.55, 0.2), (0.15, 0.3), (-0.3, 0.22), (-0.65, 0.16)] as [(CGFloat, CGFloat)] {
                    surface.addChild(patch(CGSize(width: radius * 2.4, height: radius * height),
                                           at: CGPoint(x: 0, y: radius * y), color: Palette.goldTrim.mixed(with: Palette.ember, 0.35).withAlphaComponent(0.7)))
                }
            }
            planet.addChild(saturn.node)

            // The near half of the ring passes in front of the planet.
            let frontPath = UIBezierPath(arcCenter: .zero, radius: 1, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
            frontPath.apply(CGAffineTransform(scaleX: ringSize.width / 2, y: ringSize.height / 2))
            let front = SKShapeNode(path: frontPath.cgPath)
            front.strokeColor = Palette.starlight.withAlphaComponent(0.85)
            front.lineWidth = back.lineWidth
            front.zRotation = tilt
            front.zPosition = 1
            planet.addChild(front)
        default:
            let neptune = sphere(radius: radius, fill: Palette.nebulaBlue.mixed(with: Palette.deepSpace, 0.3), edge: Palette.nebulaBlue) { surface in
                for (y, height) in [(0.5, 0.25), (0.0, 0.3), (-0.5, 0.25)] as [(CGFloat, CGFloat)] {
                    surface.addChild(patch(CGSize(width: radius * 2.4, height: radius * height),
                                           at: CGPoint(x: 0, y: radius * y), color: Palette.nebulaBlue.mixed(with: Palette.starlight, 0.3).withAlphaComponent(0.55)))
                }
                surface.addChild(patch(CGSize(width: radius * 0.5, height: radius * 0.28),
                                       at: CGPoint(x: -radius * 0.25, y: -radius * 0.2), color: Palette.deepSpace.withAlphaComponent(0.6)))
            }
            planet.addChild(neptune.node)
        }
        return planet
    }

    /// A little moon that circles a planet.
    static func moonBody(radius: CGFloat) -> SKNode {
        let random = GKMersenneTwisterRandomSource(seed: 1969)
        let moon = sphere(radius: radius, fill: moonDust, edge: Palette.starlight.withAlphaComponent(0.6)) { surface in
            for _ in 0..<5 {
                let crater = SKShapeNode(circleOfRadius: radius * CGFloat(0.08 + 0.1 * random.nextUniform()))
                crater.position = CGPoint(x: radius * CGFloat(random.nextUniform() * 1.4 - 0.7), y: radius * CGFloat(random.nextUniform() * 1.4 - 0.7))
                crater.fillColor = moonDust.mixed(with: Palette.dusk, 0.25)
                crater.strokeColor = .clear
                surface.addChild(crater)
            }
        }
        let node = SKNode()
        node.addChild(glow(color: Palette.starlight, diameter: radius * 3, alpha: 0.12))
        node.addChild(moon.node)
        return node
    }

    // MARK: - Stars and sky objects

    /// The sun: a burning core, a warm glow, and slowly turning rays.
    static func sun(radius: CGFloat, animated: Bool) -> SKNode {
        let sun = SKNode()
        sun.addChild(glow(color: Palette.ember, diameter: radius * 4.6, alpha: 0.28))
        sun.addChild(glow(color: Palette.goldTrim, diameter: radius * 3.2, alpha: 0.5))

        for (scale, direction) in [(CGFloat(2.6), CGFloat(1)), (CGFloat(2.0), CGFloat(-1))] {
            let rays = SKSpriteNode(texture: sparkle)
            rays.size = CGSize(width: radius * scale, height: radius * scale)
            rays.color = Palette.goldTrim
            rays.colorBlendFactor = 1
            rays.alpha = 0.7
            rays.zRotation = scale > 2.2 ? 0 : .pi / 4
            if animated { rays.run(.repeatForever(.rotate(byAngle: .pi * 2 * direction, duration: 60))) }
            sun.addChild(rays)
        }

        let core = SKShapeNode(circleOfRadius: radius * 0.62)
        core.fillColor = Palette.starlight.mixed(with: Palette.goldTrim, 0.35)
        core.strokeColor = Palette.goldTrim.mixed(with: Palette.starlight, 0.5)
        core.lineWidth = max(1.5, radius * 0.05)
        sun.addChild(core)
        if animated {
            sun.run(.repeatForever(.sequence([.scale(to: 1.04, duration: 2.4), .scale(to: 0.98, duration: 2.4)])))
        }
        return sun
    }

    /// A comet, heading toward the lower left with its tail streaming up and to the right.
    static func cometBody(size: CGFloat, animated: Bool) -> SKNode {
        let comet = SKNode()
        let tail = UIBezierPath()
        tail.move(to: CGPoint(x: -size * 0.1, y: size * 0.18))
        tail.addLine(to: CGPoint(x: size * 2.6, y: size * 1.7))
        tail.addLine(to: CGPoint(x: size * 0.18, y: size * 0.05))
        tail.close()
        let outer = SKShapeNode(path: tail.cgPath)
        outer.fillColor = Palette.nebulaBlue.withAlphaComponent(0.35)
        outer.strokeColor = .clear
        comet.addChild(outer)

        let inner = SKShapeNode(path: tail.cgPath)
        inner.setScale(0.7)
        inner.fillColor = Palette.starlight.withAlphaComponent(0.4)
        inner.strokeColor = .clear
        comet.addChild(inner)

        comet.addChild(glow(color: Palette.starlight, diameter: size * 1.8, alpha: 0.7))
        let head = SKShapeNode(circleOfRadius: size * 0.2)
        head.fillColor = Palette.starlight
        head.strokeColor = .clear
        comet.addChild(head)
        if animated {
            outer.run(.repeatForever(.sequence([.fadeAlpha(to: 0.6, duration: 0.9), .fadeAlpha(to: 1, duration: 0.9)])))
        }
        return comet
    }

    /// A satellite: a small box with two solar panels and a blinking light.
    static func satellite(size: CGFloat, animated: Bool) -> SKNode {
        let satellite = SKNode()
        let panelColor = Palette.nebulaBlue.mixed(with: Palette.dusk, 0.35)
        for side: CGFloat in [-1, 1] {
            let panel = SKShapeNode(rect: CGRect(x: side < 0 ? -size * 0.5 : size * 0.17, y: -size * 0.1, width: size * 0.33, height: size * 0.2), cornerRadius: 1)
            panel.fillColor = panelColor
            panel.strokeColor = Palette.nebulaBlue
            panel.lineWidth = 1
            satellite.addChild(panel)
        }
        let core = SKShapeNode(rect: CGRect(x: -size * 0.17, y: -size * 0.14, width: size * 0.34, height: size * 0.28), cornerRadius: 2)
        core.fillColor = Palette.starlight
        core.strokeColor = Palette.starlight.mixed(with: Palette.dusk, 0.4)
        core.lineWidth = 1
        satellite.addChild(core)

        let light = glow(color: Palette.ember, diameter: size * 0.4, alpha: 1)
        light.position = CGPoint(x: 0, y: size * 0.2)
        if animated { light.run(.repeatForever(.sequence([.fadeAlpha(to: 0.15, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)]))) }
        satellite.addChild(light)
        return satellite
    }

    // MARK: - Launch site

    /// A floating island of rock with a launchpad on top. The origin is the pad's surface.
    static func launchIsland(width: CGFloat, seed: UInt64, animated: Bool) -> SKNode {
        let island = SKNode()
        let random = GKMersenneTwisterRandomSource(seed: seed)

        let rock = UIBezierPath()
        rock.move(to: CGPoint(x: -width * 0.5, y: 0))
        let points = 6
        for index in 1...points {
            let t = CGFloat(index) / CGFloat(points + 1)
            let jitter = CGFloat(random.nextUniform())
            // Narrows toward a point, like a rock that's been floating a long time.
            rock.addLine(to: CGPoint(x: -width * 0.5 * (1 - t * 0.9) - width * 0.03 * jitter, y: -width * 0.6 * t * (0.9 + 0.2 * jitter)))
        }
        rock.addLine(to: CGPoint(x: 0, y: -width * 0.62))
        for index in (1...points).reversed() {
            let t = CGFloat(index) / CGFloat(points + 1)
            let jitter = CGFloat(random.nextUniform())
            rock.addLine(to: CGPoint(x: width * 0.5 * (1 - t * 0.9) + width * 0.03 * jitter, y: -width * 0.6 * t * (0.9 + 0.2 * jitter)))
        }
        rock.addLine(to: CGPoint(x: width * 0.5, y: 0))
        rock.close()

        let underside = SKShapeNode(path: rock.cgPath)
        underside.fillColor = stone
        underside.strokeColor = stone.mixed(with: Palette.starlight, 0.25)
        underside.lineWidth = 1.5
        underside.lineJoin = .round
        island.addChild(underside)
        for _ in 0..<3 {
            let crater = SKShapeNode(circleOfRadius: width * CGFloat(0.03 + 0.03 * random.nextUniform()))
            crater.position = CGPoint(x: width * CGFloat(random.nextUniform() - 0.5) * 0.5, y: -width * CGFloat(0.1 + 0.25 * random.nextUniform()))
            crater.fillColor = stone.mixed(with: Palette.deepSpace, 0.3)
            crater.strokeColor = .clear
            island.addChild(crater)
        }

        let metal = Palette.dusk.mixed(with: Palette.starlight, 0.35)
        let platform = SKShapeNode(rect: CGRect(x: -width * 0.46, y: 0, width: width * 0.92, height: width * 0.05), cornerRadius: 2)
        platform.fillColor = metal
        platform.strokeColor = metal.mixed(with: Palette.starlight, 0.3)
        platform.lineWidth = 1
        island.addChild(platform)

        let tower = SKShapeNode(rect: CGRect(x: width * 0.3, y: width * 0.05, width: width * 0.05, height: width * 0.6))
        tower.fillColor = metal.mixed(with: Palette.deepSpace, 0.2)
        tower.strokeColor = .clear
        island.addChild(tower)
        let arm = SKShapeNode(rect: CGRect(x: width * 0.12, y: width * 0.5, width: width * 0.2, height: width * 0.025))
        arm.fillColor = tower.fillColor
        arm.strokeColor = .clear
        island.addChild(arm)

        let light = glow(color: Palette.ember, diameter: width * 0.18, alpha: 0.9)
        light.position = CGPoint(x: width * 0.325, y: width * 0.66)
        if animated { light.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.6), .fadeAlpha(to: 0.9, duration: 0.6)]))) }
        island.addChild(light)

        if animated {
            let bob = SKAction.sequence([.moveBy(x: 0, y: width * 0.03, duration: 2.2), .moveBy(x: 0, y: -width * 0.03, duration: 2.2)])
            bob.timingMode = .easeInEaseOut
            island.run(.repeatForever(bob), withKey: "bob")
        }
        return island
    }

    // MARK: - Lunar surface

    /// The Moon's ground: a huge pale circle whose top edge is the surface.
    static func lunarGround(radius: CGFloat) -> SKNode {
        let ground = SKNode()
        ground.addChild(glow(color: Palette.goldTrim, diameter: radius * 2.15, alpha: 0.1))
        let surface = SKShapeNode(circleOfRadius: radius)
        surface.fillColor = moonDust.mixed(with: Palette.dusk, 0.12)
        surface.strokeColor = Palette.starlight.withAlphaComponent(0.7)
        surface.lineWidth = 3
        ground.addChild(surface)

        let random = GKMersenneTwisterRandomSource(seed: 1969)
        for _ in 0..<26 {
            // Craters near the rim, the only part that's ever on screen.
            let angle = CGFloat.pi / 2 + CGFloat(random.nextUniform() - 0.5) * 0.55
            let depth = radius * CGFloat(0.012 + 0.09 * random.nextUniform())
            let size = radius * CGFloat(0.006 + 0.016 * random.nextUniform())
            let crater = SKShapeNode(ellipseOf: CGSize(width: size * 2.4, height: size))
            crater.position = CGPoint(x: cos(angle) * (radius - depth), y: sin(angle) * (radius - depth))
            crater.zRotation = angle - .pi / 2
            crater.fillColor = moonDust.mixed(with: Palette.dusk, 0.3)
            crater.strokeColor = moonDust.mixed(with: Palette.dusk, 0.45)
            crater.lineWidth = 1
            surface.addChild(crater)
        }
        return ground
    }

    /// A rover, with its wheels on the ground at the origin.
    static func rover(size: CGFloat, animated: Bool) -> SKNode {
        let rover = SKNode()
        let wheelRadius = size * 0.1
        for x in [-0.3, 0, 0.3] as [CGFloat] {
            let wheel = SKShapeNode(circleOfRadius: wheelRadius)
            wheel.position = CGPoint(x: size * x, y: wheelRadius)
            wheel.fillColor = Palette.dusk
            wheel.strokeColor = Palette.starlight.mixed(with: Palette.dusk, 0.4)
            wheel.lineWidth = 1.5
            let spoke = SKShapeNode(rect: CGRect(x: -wheelRadius * 0.7, y: -1, width: wheelRadius * 1.4, height: 2))
            spoke.fillColor = Palette.starlight.withAlphaComponent(0.6)
            spoke.strokeColor = .clear
            wheel.addChild(spoke)
            rover.addChild(wheel)
        }

        let hull = SKShapeNode(rect: CGRect(x: -size * 0.42, y: wheelRadius * 1.5, width: size * 0.84, height: size * 0.2), cornerRadius: size * 0.04)
        hull.fillColor = Palette.starlight
        hull.strokeColor = Palette.starlight.mixed(with: Palette.dusk, 0.4)
        hull.lineWidth = 1
        rover.addChild(hull)

        let cabin = SKShapeNode(rect: CGRect(x: size * 0.02, y: wheelRadius * 1.5 + size * 0.2, width: size * 0.3, height: size * 0.14), cornerRadius: size * 0.03)
        cabin.fillColor = Palette.nebulaBlue.mixed(with: Palette.dusk, 0.2)
        cabin.strokeColor = Palette.starlight.mixed(with: Palette.dusk, 0.4)
        cabin.lineWidth = 1
        rover.addChild(cabin)

        let panel = SKShapeNode(rect: CGRect(x: -size * 0.36, y: wheelRadius * 1.5 + size * 0.2, width: size * 0.34, height: size * 0.04))
        panel.fillColor = Palette.nebulaBlue.mixed(with: Palette.dusk, 0.35)
        panel.strokeColor = Palette.nebulaBlue
        panel.lineWidth = 1
        panel.zRotation = 0.12
        rover.addChild(panel)

        let light = glow(color: Palette.goldTrim, diameter: size * 0.18, alpha: 1)
        light.position = CGPoint(x: size * 0.4, y: wheelRadius * 1.5 + size * 0.1)
        if animated { light.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)]))) }
        rover.addChild(light)
        return rover
    }

    /// A moon base: a glass dome with an antenna. Its windows light up when explored.
    static func base(size: CGFloat, animated: Bool) -> (node: SKNode, lights: SKNode) {
        let base = SKNode()
        let radius = size * 0.4

        let dome = UIBezierPath(arcCenter: .zero, radius: radius, startAngle: 0, endAngle: .pi, clockwise: true)
        dome.close()
        let shell = SKShapeNode(path: dome.cgPath)
        shell.fillColor = Palette.starlight.mixed(with: Palette.nebulaBlue, 0.3)
        shell.strokeColor = Palette.starlight
        shell.lineWidth = max(1.5, size * 0.02)
        base.addChild(shell)

        let lights = SKNode()
        lights.alpha = 0.25
        for x in [-0.55, 0, 0.55] as [CGFloat] {
            let window = SKShapeNode(circleOfRadius: radius * 0.13)
            window.position = CGPoint(x: radius * x, y: radius * 0.4)
            window.fillColor = Palette.goldTrim
            window.strokeColor = .clear
            lights.addChild(window)
            let halo = glow(color: Palette.goldTrim, diameter: radius * 0.8, alpha: 0.8)
            halo.position = window.position
            lights.addChild(halo)
        }
        base.addChild(lights)

        let door = SKShapeNode(rect: CGRect(x: -radius * 0.14, y: 0, width: radius * 0.28, height: radius * 0.3), cornerRadius: 2)
        door.fillColor = Palette.dusk
        door.strokeColor = Palette.starlight.mixed(with: Palette.dusk, 0.4)
        door.lineWidth = 1
        base.addChild(door)

        let mast = SKShapeNode(rect: CGRect(x: radius * 0.55, y: radius * 0.45, width: size * 0.015, height: radius * 0.75))
        mast.fillColor = Palette.starlight
        mast.strokeColor = .clear
        base.addChild(mast)
        let beacon = glow(color: Palette.ember, diameter: size * 0.12, alpha: 1)
        beacon.position = CGPoint(x: radius * 0.55 + size * 0.0075, y: radius * 1.2)
        if animated { beacon.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.8), .fadeAlpha(to: 1, duration: 0.8)]))) }
        base.addChild(beacon)

        let footing = SKShapeNode(rect: CGRect(x: -radius * 1.1, y: -size * 0.025, width: radius * 2.2, height: size * 0.05), cornerRadius: 2)
        footing.fillColor = Palette.dusk.mixed(with: Palette.starlight, 0.3)
        footing.strokeColor = .clear
        base.addChild(footing)
        return (base, lights)
    }

    /// A small flag planted by an explorer. The origin is the bottom of the pole.
    static func flag(height: CGFloat) -> SKNode {
        let flag = SKNode()
        let pole = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 1.5, height: height))
        pole.fillColor = Palette.starlight
        pole.strokeColor = .clear
        flag.addChild(pole)
        let cloth = UIBezierPath()
        cloth.move(to: CGPoint(x: 1.5, y: height))
        cloth.addLine(to: CGPoint(x: height * 0.6, y: height * 0.82))
        cloth.addLine(to: CGPoint(x: 1.5, y: height * 0.64))
        cloth.close()
        let banner = SKShapeNode(path: cloth.cgPath)
        banner.fillColor = Palette.ember
        banner.strokeColor = .clear
        flag.addChild(banner)
        return flag
    }

    // MARK: - Space fabric

    /// The grid texture that bends under the weight of planets and the rocket's movement.
    static func fabricTexture(size: CGSize, cell: CGFloat) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            cg.setStrokeColor(Palette.nebulaBlue.cgColor)
            cg.setLineWidth(1.5)
            var x: CGFloat = 0
            while x <= size.width + 0.5 {
                cg.move(to: CGPoint(x: x, y: 0))
                cg.addLine(to: CGPoint(x: x, y: size.height))
                x += cell
            }
            var y: CGFloat = 0
            while y <= size.height + 0.5 {
                cg.move(to: CGPoint(x: 0, y: y))
                cg.addLine(to: CGPoint(x: size.width, y: y))
                y += cell
            }
            cg.strokePath()
        }
        return SKTexture(image: image)
    }
}
