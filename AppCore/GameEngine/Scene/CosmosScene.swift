//
//  CosmosScene.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-10-01.
//

import SpriteKit
import GameplayKit
import UIKit

// The SpriteKit stage. It never decides anything: it draws the World it's given, and each
// StepEvent decides how the newest thing arrives.
//
// - create glows into being, build assembles piece by piece, spawn pops in, summon streaks down
// - existing things slide over to make room, so the universe visibly grows
// - launch lifts off, orbit swings a rocket around a planet, explore lands and drives
// - move ripples the fabric of space
// - tapping anything shows which line of code made it

final class CosmosScene: SKScene {
    /// Called with a line number when the player taps something that code created.
    var onThingTapped: ((Int) -> Void)?

    var style = SceneStyle() {
        didSet { if style != oldValue { relayout() } }
    }

    private struct Visual {
        let node: SKNode
        let builtSize: CGFloat
        var lights: SKNode?
    }

    private struct Motion {
        var target: Orbit
        var center: CGPoint
        var radius: CGFloat
        var angle: Double
        var isActive: Bool
    }

    private var world: World?
    private var layout = CosmosLayout()
    private var visuals: [Int: Visual] = [:]
    private var motions: [Int: Motion] = [:]
    private var lineForBody: [Int: Int] = [:]
    private var plantedFlags: Set<Int> = []
    private var highlightedLine: Int?

    private var clock: TimeInterval = 0
    private var lastUpdate: TimeInterval?

    private let cameraNode = SKCameraNode()
    private let backdropLayer = SKNode()
    private let fabric = SpaceFabric()
    private let decorLayer = SKNode()
    private let ringLayer = SKNode()
    private let objectLayer = SKNode()
    private let effectLayer = SKNode()
    private let ghostLayer = SKNode()
    private var groundNode: SKNode?

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = Palette.deepSpace

        let layers: [SKNode] = [backdropLayer, fabric, decorLayer, ringLayer, objectLayer, ghostLayer, effectLayer]
        for (depth, layer) in layers.enumerated() {
            layer.zPosition = CGFloat(depth)
            addChild(layer)
        }
        addChild(cameraNode)
        camera = cameraNode
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        relayout()
    }

    // MARK: - Loading

    /// Shows a starting universe, clearing everything from the last run.
    func load(_ world: World) {
        objectLayer.removeAllChildren()
        ringLayer.removeAllChildren()
        ghostLayer.removeAllChildren()
        effectLayer.removeAllChildren()
        groundNode?.removeFromParent()
        groundNode = nil
        visuals = [:]
        motions = [:]
        lineForBody = [:]
        plantedFlags = []
        highlightedLine = nil
        backdropLayer.position = .zero
        self.world = world
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        reconcile(to: world, animated: false)
    }

    private func relayout() {
        guard size.width > 1, size.height > 1 else { return }
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        buildBackdrop()
        guard let world else { return }
        let lines = lineForBody
        load(world)
        lineForBody = lines
    }

    /// Where something is on the stage, from 0 (left) to 1 (right), for stereo sound.
    func horizontalPosition(of body: Int) -> Float {
        guard size.width > 1, let point = visuals[body]?.node.position ?? layout.placements[body]?.position else { return 0.5 }
        return Float(point.x / size.width)
    }

    private func buildBackdrop() {
        backdropLayer.removeAllChildren()
        // A fixed seed keeps the stars in the same place every time.
        let random = GKMersenneTwisterRandomSource(seed: 2027)
        let bleed: CGFloat = 1.3

        for color in [Palette.nebulaBlue, Palette.ember, Palette.goldTrim] {
            let nebula = SceneArt.glow(color: color, diameter: max(size.width, size.height) * 0.8, alpha: 0.08)
            nebula.position = CGPoint(x: size.width * CGFloat(random.nextUniform()), y: size.height * CGFloat(random.nextUniform()))
            backdropLayer.addChild(nebula)
        }

        let count = min(240, max(70, Int(size.width * size.height / 3200)))
        for _ in 0..<count {
            let star = SKSpriteNode(texture: SceneArt.softDot)
            let diameter = CGFloat(2 + random.nextUniform() * 4)
            star.size = CGSize(width: diameter, height: diameter)
            let brightness = CGFloat(0.25 + 0.7 * random.nextUniform())
            star.alpha = brightness
            star.position = CGPoint(x: size.width * (CGFloat(random.nextUniform()) * bleed - (bleed - 1) / 2),
                                    y: size.height * (CGFloat(random.nextUniform()) * bleed - (bleed - 1) / 2))
            if !style.reduceMotion && random.nextUniform() < 0.3 {
                let duration = Double(1 + 2 * random.nextUniform())
                star.run(.repeatForever(.sequence([.fadeAlpha(to: 0.1, duration: duration), .fadeAlpha(to: brightness, duration: duration)])))
            }
            backdropLayer.addChild(star)
        }
    }

    // MARK: - Per-frame motion

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdate.map { min(currentTime - $0, 0.1) } ?? 0
        lastUpdate = currentTime
        clock += delta
        fabric.update(deltaTime: delta)

        let smoothing = CGFloat(min(1, delta * 5))
        for (id, var motion) in motions {
            guard let node = visuals[id]?.node else { continue }
            motion.center.x += (motion.target.center.x - motion.center.x) * smoothing
            motion.center.y += (motion.target.center.y - motion.center.y) * smoothing
            motion.radius += (motion.target.radius - motion.radius) * smoothing
            if motion.isActive {
                if !style.reduceMotion { motion.angle += delta * 2 * .pi / motion.target.period }
                node.position = CGPoint(x: motion.center.x + cos(motion.angle) * motion.radius,
                                        y: motion.center.y + sin(motion.angle) * motion.radius)
                // A rocket in orbit points along its path.
                if node is RocketNode { node.zRotation = motion.angle }
            }
            motions[id] = motion
        }
    }

    // MARK: - Building the universe

    private func makeVisual(for body: Body, placement: Placement, in world: World) -> Visual {
        let animated = !style.reduceMotion
        let size = placement.size
        let node: SKNode
        var lights: SKNode?
        var builtSize = size
        switch body.thing {
        case .launchpad:
            node = SceneArt.launchIsland(width: size, seed: UInt64(body.id) * 7 + 3, animated: animated)
            node.zPosition = 1
        case .rocket:
            let rocket = RocketNode()
            rocket.reset(launched: body.flight != .grounded, reduceMotion: style.reduceMotion)
            if body.flight == .landed { rocket.land() }
            rocket.configure(height: size)
            rocket.zPosition = 6
            node = rocket
            builtSize = size
        case .planet:
            let index = world.planets.firstIndex { $0.id == body.id } ?? 0
            node = SceneArt.planet(radius: size / 2, style: index, animated: animated)
            node.zPosition = 2
        case .moon:
            node = SceneArt.moonBody(radius: size)
            node.zPosition = 3
        case .satellite:
            node = SceneArt.satellite(size: size, animated: animated)
            node.zPosition = 4
        case .star:
            node = SceneArt.sun(radius: size, animated: animated)
            node.zPosition = 0.5
        case .asteroid:
            node = SceneArt.asteroid(cellSize: size / 0.68, seed: UInt64(body.id) * 31 + 5, animated: animated)
            node.zPosition = 1
        case .comet:
            node = SceneArt.cometBody(size: size, animated: animated)
            node.zPosition = 1
            if animated {
                let drift = SKAction.sequence([.moveBy(x: -size * 1.5, y: -size * 0.9, duration: 5), .moveBy(x: size * 1.5, y: size * 0.9, duration: 0)])
                node.run(.repeatForever(drift))
            }
        case .rover:
            node = SceneArt.rover(size: size, animated: animated)
            node.zPosition = 4
        case .base:
            let base = SceneArt.base(size: size, animated: animated)
            node = base.node
            lights = base.lights
            node.zPosition = 3
        }
        return Visual(node: node, builtSize: builtSize, lights: lights)
    }

    /// The scale that makes a visual match its placement. Things shrink to make room as more arrive.
    private func scale(for visual: Visual, placement: Placement) -> CGFloat {
        if visual.node is RocketNode { return RocketNode.scale(forHeight: placement.size) }
        return placement.size / max(visual.builtSize, 1)
    }

    /// Makes the scene match a world: new things arrive, existing things move to their new spots.
    /// Anything in `claimed` is left alone, because an event is animating it by hand.
    private func reconcile(to newWorld: World, animated: Bool, duration: TimeInterval = 0.8,
                           claimed: Set<Int> = [], delayMoves: TimeInterval = 0) {
        let newLayout = CosmosLayout.arrange(newWorld, in: size)
        let animated = animated && !style.reduceMotion
        let ids = Set(newWorld.bodies.map(\.id))

        for id in visuals.keys where !ids.contains(id) {
            visuals[id]?.node.removeFromParent()
            visuals[id] = nil
            motions[id] = nil
        }

        updateGround(newLayout, animated: animated, duration: duration)

        for body in newWorld.bodies {
            guard let placement = newLayout.placements[body.id] else { continue }
            let targetScale: CGFloat

            if var visual = visuals[body.id] {
                targetScale = scale(for: visual, placement: placement)
                if !claimed.contains(body.id) {
                    move(visual.node, to: placement, scale: targetScale, animated: animated, duration: duration, delay: delayMoves)
                }
                if body.explored { light(&visual, animated: animated, delay: duration * 0.8) }
                visuals[body.id] = visual
            } else {
                var visual = makeVisual(for: body, placement: placement, in: newWorld)
                targetScale = scale(for: visual, placement: placement)
                visual.node.position = placement.position
                visual.node.setScale(targetScale)
                visual.node.zRotation = placement.rotation
                objectLayer.addChild(visual.node)
                if body.explored { light(&visual, animated: false, delay: 0) }
                visuals[body.id] = visual
                if animated {
                    arrive(visual, body: body, placement: placement, scale: targetScale, duration: duration)
                }
            }

            if let orbit = placement.orbit {
                register(orbit: orbit, for: body.id, activateAfter: (animated && !claimed.contains(body.id)) ? duration : 0)
            }
        }

        layout = newLayout
        world = newWorld
        rebuildRings(newLayout, world: newWorld)
        fabric.configure(size: size, masses: newLayout.masses, reduceMotion: style.reduceMotion, highContrast: style.highContrast)
        let shift = newWorld.rockets.reduce(CGPoint.zero) { CGPoint(x: $0.x + CGFloat($1.shiftX), y: $0.y + CGFloat($1.shiftY)) }
        let parallax = CGPoint(x: -shift.x * layout.unit * 0.03, y: -shift.y * layout.unit * 0.03)
        if animated {
            backdropLayer.run(.move(to: parallax, duration: duration * 0.8), withKey: "parallax")
        } else {
            backdropLayer.position = parallax
        }
        applyHighlight()
    }

    private func move(_ node: SKNode, to placement: Placement, scale: CGFloat, animated: Bool, duration: TimeInterval, delay: TimeInterval) {
        guard !(motions.first { visuals[$0.key]?.node === node }?.value.isActive ?? false) else {
            node.run(.scale(to: scale, duration: animated ? duration : 0), withKey: "scale")
            return
        }
        if animated {
            let slide = SKAction.group([
                .move(to: placement.position, duration: duration),
                .scale(to: scale, duration: duration),
                .rotate(toAngle: placement.rotation, duration: duration, shortestUnitArc: true)
            ])
            slide.timingMode = .easeInEaseOut
            node.run(.sequence([.wait(forDuration: delay), slide]), withKey: "layout")
        } else {
            node.removeAction(forKey: "layout")
            node.position = placement.position
            node.setScale(scale)
            node.zRotation = placement.rotation
        }
    }

    private func register(orbit: Orbit, for id: Int, activateAfter delay: TimeInterval) {
        if var existing = motions[id] {
            existing.target = orbit
            motions[id] = existing
            return
        }
        let start = orbit.position(at: 0)
        var motion = Motion(target: orbit, center: orbit.center, radius: orbit.radius,
                            angle: atan2(start.y - orbit.center.y, start.x - orbit.center.x), isActive: delay == 0)
        if delay > 0 {
            run(.sequence([.wait(forDuration: delay), .run { [weak self] in self?.activate(id) }]))
        }
        motion.isActive = delay == 0
        motions[id] = motion
    }

    /// Starts an orbit from wherever the thing is now, so it never jumps.
    private func activate(_ id: Int) {
        guard var motion = motions[id], let node = visuals[id]?.node else { return }
        motion.angle = atan2(node.position.y - motion.center.y, node.position.x - motion.center.x)
        motion.radius = hypot(node.position.x - motion.center.x, node.position.y - motion.center.y)
        motion.isActive = true
        motions[id] = motion
    }

    private func rebuildRings(_ layout: CosmosLayout, world: World) {
        ringLayer.removeAllChildren()
        var seen: Set<String> = []
        for (id, placement) in layout.placements {
            guard let orbit = placement.orbit, world.body(id)?.isRocket == false else { continue }
            let key = "\(Int(orbit.center.x))-\(Int(orbit.radius))"
            guard seen.insert(key).inserted else { continue }
            let ring = SKShapeNode(circleOfRadius: orbit.radius)
            ring.path = ring.path?.copy(dashingWithPhase: 0, lengths: [3, 7])
            ring.position = orbit.center
            ring.strokeColor = Palette.starlight.withAlphaComponent(style.highContrast ? 0.5 : 0.16)
            ring.lineWidth = 1
            ringLayer.addChild(ring)
        }
    }

    // MARK: - The Moon's ground

    private func updateGround(_ newLayout: CosmosLayout, animated: Bool, duration: TimeInterval) {
        guard let ground = newLayout.ground else {
            groundNode?.removeFromParent()
            groundNode = nil
            return
        }
        let target = ground.center
        if let groundNode {
            groundNode.position = target
            return
        }
        let node = SceneArt.lunarGround(radius: ground.radius)
        node.position = target
        node.zPosition = 1
        decorLayer.addChild(node)
        groundNode = node
        if animated {
            // The Moon rises from below, as if it had been waiting just out of sight.
            node.position = CGPoint(x: target.x, y: target.y - size.height * 0.4)
            let rise = SKAction.move(to: target, duration: duration)
            rise.timingMode = .easeOut
            node.run(rise)
            shake(amount: layout.unit * 0.012)
        }
        addEarthBackdrop(animated: animated)
    }

    private func addEarthBackdrop(animated: Bool) {
        guard decorLayer.childNode(withName: "earth") == nil else { return }
        let earth = SceneArt.planet(radius: layout.unit * 0.075, style: 0, animated: !style.reduceMotion)
        earth.name = "earth"
        earth.position = CGPoint(x: size.width * 0.5, y: size.height * 0.8)
        earth.zPosition = 0.5
        decorLayer.addChild(earth)
        if animated {
            earth.alpha = 0
            earth.run(.fadeIn(withDuration: 1.2))
        }
    }

    // MARK: - Arrivals

    /// Each way of making something has its own entrance.
    private func arrive(_ visual: Visual, body: Body, placement: Placement, scale target: CGFloat, duration: TimeInterval) {
        let node = visual.node
        let size = max(placement.size, 24)
        let spot = placement.position

        if body.autoBuilt {
            // launch() noticed there was no pad and slides one in beneath the rocket.
            node.position = CGPoint(x: spot.x, y: spot.y - size)
            node.alpha = 0
            let rise = SKAction.move(to: spot, duration: duration * 0.7)
            rise.timingMode = .easeOut
            node.run(.group([rise, .fadeIn(withDuration: duration * 0.4)]))
            dust(at: spot, size: size)
            return
        }

        switch body.verb {
        case .create:
            node.alpha = 0
            node.setScale(target * 0.3)
            let grow = SKAction.scale(to: target, duration: duration * 0.6)
            grow.timingMode = .easeOut
            node.run(.group([.fadeIn(withDuration: duration * 0.6), grow]))
            let flash = SceneArt.glow(color: Palette.starlight, diameter: size * 2.4, alpha: 0)
            flash.position = spot
            flash.run(.sequence([.fadeAlpha(to: 0.8, duration: duration * 0.25), .fadeOut(withDuration: duration * 0.5), .removeFromParent()]))
            effectLayer.addChild(flash)
            sparkles(at: spot, size: size)

        case .build:
            // Piece by piece, from the bottom up, with a little dust and sparks as it goes.
            let parts = node.children.flatMap { $0.children.isEmpty ? [$0] : $0.children }
            let lift = size * 0.25 / max(target, 0.01)
            for (index, part) in parts.enumerated() {
                let delay = min(duration * 0.6, Double(index) * 0.1)
                let finalAlpha = part.alpha
                part.alpha = 0
                part.position.y -= lift
                part.run(.sequence([.wait(forDuration: delay), .group([.fadeAlpha(to: finalAlpha, duration: 0.25), .moveBy(x: 0, y: lift, duration: 0.3)])]))
            }
            dust(at: CGPoint(x: spot.x, y: spot.y - size * 0.2), size: size)
            sparkles(at: spot, size: size, colors: [Palette.goldTrim, Palette.ember])

        case .spawn:
            node.setScale(0.001)
            let pop = SKAction.scale(to: target * 1.25, duration: 0.18)
            pop.timingMode = .easeOut
            node.run(.sequence([pop, .scale(to: target, duration: 0.14)]))
            ping(at: spot, size: size, color: Palette.nebulaBlue)

        case .summon:
            // Streaks down from the stars with a glowing tail, and lands with a flash.
            node.position = CGPoint(x: spot.x + size * 0.4, y: self.size.height + size)
            let streak = SKSpriteNode(texture: SceneArt.softDot)
            streak.color = Palette.goldTrim
            streak.colorBlendFactor = 1
            streak.blendMode = .add
            streak.anchorPoint = CGPoint(x: 0.5, y: 0)
            streak.size = CGSize(width: size * 0.5 / max(target, 0.01), height: size * 4 / max(target, 0.01))
            streak.position = CGPoint(x: 0, y: 0)
            streak.alpha = 0.8
            node.addChild(streak)
            let fall = SKAction.move(to: spot, duration: duration * 0.45)
            fall.timingMode = .easeIn
            node.run(.sequence([fall, .run { [weak self, weak streak] in
                streak?.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
                self?.ping(at: spot, size: size, color: Palette.goldTrim)
                self?.sparkles(at: spot, size: size, colors: [Palette.goldTrim, Palette.starlight])
                self?.shake(amount: size * 0.08)
            }]))
        }

        if body.thing == .planet, let world {
            let index = world.planets.firstIndex { $0.id == body.id } ?? 0
            nameTag(World.planetNames[index % World.planetNames.count], at: CGPoint(x: spot.x, y: spot.y + size * 0.75))
        }
    }

    private func nameTag(_ text: String, at point: CGPoint) {
        let label = SceneArt.label(text, size: 13, color: Palette.starlight)
        label.position = point
        label.alpha = 0
        label.run(.sequence([.fadeIn(withDuration: 0.4), .moveBy(x: 0, y: 10, duration: 1.4), .fadeOut(withDuration: 0.5), .removeFromParent()]))
        effectLayer.addChild(label)
    }

    private func sparkles(at point: CGPoint, size: CGFloat, colors: [UIColor] = [Palette.goldTrim, Palette.starlight]) {
        let burst = SceneArt.burst(colors: colors, count: style.reduceMotion ? 8 : 22, speed: size * 0.9, lifetime: 0.9,
                                   size: max(size * 0.14, 6), texture: SceneArt.sparkle)
        burst.position = point
        effectLayer.addChild(burst)
    }

    private func dust(at point: CGPoint, size: CGFloat) {
        let puff = SceneArt.burst(colors: [Palette.starlight, Palette.dusk.mixed(with: Palette.starlight, 0.4)],
                                  count: style.reduceMotion ? 10 : 36, speed: size * 0.8, lifetime: 1.0, size: size * 0.3)
        puff.position = point
        effectLayer.addChild(puff)
    }

    private func ping(at point: CGPoint, size: CGFloat, color: UIColor) {
        let ring = SKShapeNode(circleOfRadius: size * 0.3)
        ring.position = point
        ring.strokeColor = color
        ring.lineWidth = 2.5
        ring.run(.sequence([.group([.scale(to: 2.8, duration: 0.6), .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
        effectLayer.addChild(ring)
    }

    private func light(_ visual: inout Visual, animated: Bool, delay: TimeInterval) {
        guard let lights = visual.lights, lights.alpha < 1, lights.action(forKey: "lit") == nil else { return }
        if animated {
            lights.run(.sequence([.wait(forDuration: delay), .fadeIn(withDuration: 0.5)]), withKey: "lit")
        } else {
            lights.alpha = 1
        }
    }

    // MARK: - Playing events

    func play(_ event: StepEvent, duration: TimeInterval) {
        clearGhosts()
        if highlightedLine != nil { highlightLine(nil) }

        switch event.kind {
        case .created(let body):
            lineForBody[body.id] = event.line
            let isPad = body.thing == .launchpad
            reconcile(to: event.world, animated: true, duration: duration * 0.7, delayMoves: isPad ? duration * 0.35 : 0)

        case .launched(let rockets):
            reconcile(to: event.world, animated: true, duration: duration, claimed: Set(rockets))
            for id in rockets { lift(rocket: id, duration: duration) }

        case .orbited(let planet, let rockets, let createdPlanet):
            if createdPlanet { lineForBody[planet.id] = event.line }
            reconcile(to: event.world, animated: true, duration: duration * 0.3, claimed: Set(rockets))
            for id in rockets { swing(rocket: id, into: planet.id, delay: createdPlanet ? duration * 0.3 : 0, duration: duration * 0.6) }

        case .explored(let landed, let rovers, _):
            reconcile(to: event.world, animated: true, duration: duration * 0.4, claimed: Set(landed + rovers))
            explore(landed: landed, rovers: rovers, world: event.world, duration: duration)

        case .moved(let rockets, _):
            reconcile(to: event.world, animated: true, duration: duration * 0.8)
            for id in rockets {
                guard let visual = visuals[id], let rocket = visual.node as? RocketNode else { continue }
                rocket.boost(for: duration * 0.7)
                rocket.react(after: duration * 0.7)
                fabric.ripple(at: rocket.position)
                run(.sequence([.wait(forDuration: duration * 0.6), .run { [weak self, weak rocket] in
                    if let rocket { self?.fabric.ripple(at: rocket.position, strength: 0.8) }
                }]))
            }

        case .sensed(let condition, _, let preview):
            imagine(condition, preview: preview, duration: duration)

        case .loopIterationStarted, .loopIterationEnded:
            break

        case .runtimeError:
            playConfused()

        case .easterEgg(let egg):
            playEasterEgg(egg)
        }
    }

    /// The rocket rises off its pad. Smoke billows and the camera shudders.
    private func lift(rocket id: Int, duration: TimeInterval) {
        guard let rocket = visuals[id]?.node as? RocketNode, let placement = layout.placements[id] else { return }
        rocket.enter(FlyingState.self)
        rocket.boost(for: duration * 0.8)
        let start = rocket.position
        dust(at: CGPoint(x: start.x, y: start.y - placement.size * 0.5), size: placement.size * 1.2)
        shake(amount: layout.unit * 0.012)
        fabric.ripple(at: start, strength: 1.2)

        let rise = SKAction.move(to: placement.position, duration: duration * 0.8)
        rise.timingMode = .easeIn
        rocket.run(rise, withKey: "layout")
    }

    /// The rocket curves out to a planet's ring and joins it.
    private func swing(rocket id: Int, into planetID: Int, delay: TimeInterval, duration: TimeInterval) {
        guard let rocket = visuals[id]?.node as? RocketNode, let placement = layout.placements[id], let orbit = placement.orbit else { return }
        rocket.enter(FlyingState.self)
        rocket.setFlame(.cruise)
        rocket.boost(for: duration)
        let entry = orbit.position(at: 0)
        let heading = atan2(entry.y - rocket.position.y, entry.x - rocket.position.x) - .pi / 2
        let curve = SKAction.group([
            .move(to: entry, duration: duration),
            .rotate(toAngle: heading, duration: duration * 0.4, shortestUnitArc: true)
        ])
        curve.timingMode = .easeInEaseOut
        rocket.run(.sequence([.wait(forDuration: delay), curve, .run { [weak self] in
            self?.activate(id)
            self?.ping(at: entry, size: placement.size, color: Palette.goldTrim)
            self?.fabric.ripple(at: entry, strength: 0.8)
        }]), withKey: "layout")
    }

    /// The rocket touches down, the rover rolls to the base, and the base lights up.
    private func explore(landed: [Int], rovers: [Int], world: World, duration: TimeInterval) {
        for id in landed {
            guard let rocket = visuals[id]?.node as? RocketNode, let placement = layout.placements[id] else { continue }
            rocket.boost(for: duration * 0.3)
            let descend = SKAction.group([.move(to: placement.position, duration: duration * 0.4),
                                          .rotate(toAngle: placement.rotation, duration: duration * 0.4)])
            descend.timingMode = .easeOut
            rocket.run(.sequence([descend, .run { [weak self, weak rocket] in
                rocket?.land()
                self?.dust(at: CGPoint(x: placement.position.x, y: placement.position.y - placement.size * 0.5), size: placement.size)
                self?.shake(amount: placement.size * 0.05)
            }]), withKey: "layout")
        }
        for id in rovers {
            guard let node = visuals[id]?.node, let placement = layout.placements[id] else { continue }
            let drive = SKAction.move(to: placement.position, duration: duration * 0.4)
            drive.timingMode = .easeInEaseOut
            let delay = landed.isEmpty ? 0 : duration * 0.4
            node.run(.sequence([.wait(forDuration: delay), drive, .run { [weak self] in
                self?.plantFlag(near: placement, rover: id)
            }]), withKey: "layout")
        }
        if landed.isEmpty && rovers.isEmpty { return }
        run(.sequence([.wait(forDuration: duration * 0.85), .run { [weak self] in
            guard let self else { return }
            for visual in self.visuals.values { self.sparkles(at: visual.node.position, size: 40) }
        }]))
    }

    private func plantFlag(near placement: Placement, rover id: Int) {
        guard plantedFlags.insert(id).inserted else { return }
        let flag = SceneArt.flag(height: layout.unit * 0.09)
        let x = placement.position.x + placement.size * 0.75
        flag.position = CGPoint(x: x, y: layout.surface(at: x))
        flag.zRotation = layout.tilt(at: x)
        flag.zPosition = 3
        flag.setScale(0.01)
        objectLayer.addChild(flag)
        flag.run(.scale(to: 1, duration: 0.3))
        sparkles(at: flag.position, size: 40)
    }

    /// `if` asks the universe a question, and the thing in question flickers into view.
    private func imagine(_ condition: Condition, preview: World?, duration: TimeInterval) {
        let existing = world?.bodies(of: condition.thing) ?? []
        for body in existing {
            guard let node = visuals[body.id]?.node else { continue }
            let base = node.xScale
            node.run(.sequence([.scale(to: base * 1.18, duration: 0.15), .scale(to: base, duration: 0.25)]))
            ping(at: node.position, size: layout.placements[body.id]?.size ?? 40, color: condition.negated ? Palette.ember : Palette.nebulaBlue)
        }
        if existing.isEmpty, let preview {
            showGhosts(of: preview, linger: duration * 0.7)
        } else if existing.isEmpty {
            ping(at: CGPoint(x: size.width / 2, y: size.height / 2), size: 60, color: condition.negated ? Palette.nebulaBlue : Palette.ember)
        }
    }

    // MARK: - Ghosts

    /// Draws faint outlines of what a hint or an `if` is imagining.
    func showGhosts(of preview: World?, linger: TimeInterval? = nil) {
        clearGhosts()
        guard let preview, let current = world else { return }
        let imagined = CosmosLayout.arrange(preview, in: size)
        let known = Set(current.bodies.map(\.id))
        for body in preview.bodies where !known.contains(body.id) {
            guard let placement = imagined.placements[body.id] else { continue }
            let visual = makeVisual(for: body, placement: placement, in: preview)
            let node = visual.node
            node.position = placement.position
            node.setScale(scale(for: visual, placement: placement))
            node.zRotation = placement.rotation
            node.alpha = 0
            node.run(.sequence([.fadeAlpha(to: 0.4, duration: 0.3),
                                .repeat(.sequence([.fadeAlpha(to: 0.22, duration: 0.8), .fadeAlpha(to: 0.45, duration: 0.8)]), count: linger == nil ? 100 : 1)]))
            if let linger { node.run(.sequence([.wait(forDuration: linger), .fadeOut(withDuration: 0.3), .removeFromParent()])) }
            ghostLayer.addChild(node)

            let outline = SKShapeNode(circleOfRadius: max(placement.size * 0.55, 20))
            outline.path = outline.path?.copy(dashingWithPhase: 0, lengths: [5, 6])
            outline.position = placement.position
            outline.strokeColor = Palette.goldTrim.withAlphaComponent(0.8)
            outline.lineWidth = 1.5
            outline.alpha = 0
            outline.run(.sequence([.fadeIn(withDuration: 0.3), .wait(forDuration: linger ?? 3600)]))
            if let linger { outline.run(.sequence([.wait(forDuration: linger), .fadeOut(withDuration: 0.3), .removeFromParent()])) }
            ghostLayer.addChild(outline)
        }
    }

    func clearGhosts() {
        ghostLayer.removeAllChildren()
    }

    // MARK: - Highlighting what code made

    /// Dims everything except what one line of code created, and labels it with the line number.
    func highlightLine(_ line: Int?) {
        highlightedLine = line
        applyHighlight()
    }

    private func applyHighlight() {
        for visual in visuals.values {
            visual.node.childNode(withName: "lineTag")?.removeFromParent()
        }
        guard let line = highlightedLine else {
            for visual in visuals.values { visual.node.alpha = 1 }
            return
        }
        for (id, visual) in visuals {
            guard lineForBody[id] == line else {
                visual.node.alpha = 0.25
                continue
            }
            visual.node.alpha = 1
            let tag = SceneArt.label("\(line)", size: 12, color: Palette.deepSpace)
            let badge = SKShapeNode(circleOfRadius: 11)
            badge.fillColor = Palette.goldTrim
            badge.strokeColor = .clear
            badge.zPosition = -1
            tag.addChild(badge)
            tag.name = "lineTag"
            tag.zPosition = 10
            // Cancel out the thing's own scale so the badge stays a readable size.
            let scale = max(visual.node.xScale, 0.01)
            tag.setScale(1 / scale)
            tag.position = CGPoint(x: 0, y: (layout.placements[id]?.size ?? 40) * 0.6 / scale)
            visual.node.addChild(tag)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        var closest: (line: Int, distance: CGFloat)?
        for (id, visual) in visuals {
            guard let line = lineForBody[id] else { continue }
            let radius = max(28, (layout.placements[id]?.size ?? 40) * 0.6)
            let distance = hypot(visual.node.position.x - location.x, visual.node.position.y - location.y)
            if distance < radius && distance < (closest?.distance ?? .infinity) { closest = (line, distance) }
        }
        if let closest {
            onThingTapped?(closest.line)
        } else if let highlightedLine {
            onThingTapped?(highlightedLine)
        }
    }

    // MARK: - Mistakes, surprises, and winning

    /// The rocket wobbles and a ring ripples out when code asks for something impossible.
    private func playConfused() {
        for case let rocket as RocketNode in visuals.values.map(\.node) {
            rocket.run(.sequence([
                .rotate(byAngle: 0.2, duration: 0.08), .rotate(byAngle: -0.4, duration: 0.12),
                .rotate(byAngle: 0.4, duration: 0.12), .rotate(byAngle: -0.2, duration: 0.08)
            ]))
        }
        ping(at: CGPoint(x: size.width / 2, y: size.height / 2), size: layout.unit * 0.3, color: Palette.ember)
        fabric.ripple(at: CGPoint(x: size.width / 2, y: size.height / 2), strength: 0.7)
    }

    private func playEasterEgg(_ egg: EasterEgg) {
        let rocket = visuals.values.compactMap { $0.node as? RocketNode }.first
        switch egg {
        case .hello:
            rocket?.wave()
        case .suitUp:
            rocket?.suitUp()
        case .stargaze:
            drawBigDipper()
        }
        let origin = rocket?.position ?? CGPoint(x: size.width / 2, y: size.height / 2)
        sparkles(at: origin, size: 60)
    }

    /// Seven stars appear in the sky and join into the Big Dipper, then slowly fade away.
    private func drawBigDipper() {
        effectLayer.childNode(withName: "dipper")?.removeFromParent()
        let dipper = SKNode()
        dipper.name = "dipper"
        let stars: [CGPoint] = [(0.18, 0.80), (0.29, 0.83), (0.39, 0.80), (0.48, 0.74), (0.51, 0.62), (0.66, 0.60), (0.68, 0.73)]
            .map { CGPoint(x: size.width * $0.0, y: size.height * $0.1) }
        let path = CGMutablePath()
        path.addLines(between: stars)
        path.addLine(to: stars[3])
        let lines = SKShapeNode(path: path)
        lines.strokeColor = Palette.starlight.withAlphaComponent(0.45)
        lines.lineWidth = 1.5
        lines.lineJoin = .round
        lines.alpha = 0
        lines.run(.sequence([.wait(forDuration: Double(stars.count) * 0.15), .fadeIn(withDuration: 0.6)]))
        dipper.addChild(lines)
        for (index, position) in stars.enumerated() {
            let star = SKSpriteNode(texture: SceneArt.sparkle)
            star.size = CGSize(width: 22, height: 22)
            star.color = Palette.goldTrim
            star.colorBlendFactor = 1
            star.position = position
            star.setScale(0)
            star.run(.sequence([.wait(forDuration: Double(index) * 0.15), .scale(to: 1, duration: 0.3)]))
            dipper.addChild(star)
        }
        dipper.run(.sequence([.wait(forDuration: 7), .fadeOut(withDuration: 1.5), .removeFromParent()]))
        effectLayer.addChild(dipper)
    }

    /// Joins everything you made into a constellation, in the order you made it.
    func celebrate() {
        let ordered = (world?.bodies ?? []).compactMap { body -> CGPoint? in
            guard let visual = visuals[body.id] else { return nil }
            return layout.placements[body.id]?.orbit == nil ? visual.node.position : nil
        }
        if ordered.count > 1 {
            let path = CGMutablePath()
            path.addLines(between: ordered)
            let line = SKShapeNode(path: path.copy(dashingWithPhase: 0, lengths: [4, 6]))
            line.strokeColor = Palette.starlight.withAlphaComponent(0.55)
            line.lineWidth = 1.5
            line.alpha = 0
            line.run(.sequence([.wait(forDuration: 0.5), .fadeIn(withDuration: 0.8)]))
            effectLayer.addChild(line)
        }

        for (index, visual) in visuals.values.enumerated() {
            let node = visual.node
            let base = node.xScale
            if !style.reduceMotion {
                node.run(.sequence([.wait(forDuration: Double(index) * 0.08), .scale(to: base * 1.1, duration: 0.2), .scale(to: base, duration: 0.3)]))
            }
            let star = SKSpriteNode(texture: SceneArt.sparkle)
            star.size = CGSize(width: 22, height: 22)
            star.color = Palette.starlight
            star.colorBlendFactor = 1
            star.position = node.position
            star.setScale(0)
            star.run(.sequence([.wait(forDuration: Double(index) * 0.08), .scale(to: 1, duration: 0.25)]))
            effectLayer.addChild(star)
        }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let rain = SceneArt.burst(colors: [Palette.starlight, Palette.goldTrim, Palette.goldTrim], count: style.reduceMotion ? 20 : 60,
                                  speed: layout.unit * 0.6, lifetime: 1.6, size: 12, texture: SceneArt.sparkle)
        rain.position = center
        effectLayer.addChild(rain)
        fabric.ripple(at: center, strength: 1.4)
    }

    // MARK: - Camera

    private func shake(amount: CGFloat) {
        guard !style.reduceMotion else { return }
        var moves: [SKAction] = []
        for _ in 0..<6 {
            let dx = CGFloat.random(in: -amount...amount), dy = CGFloat.random(in: -amount...amount)
            moves.append(.moveBy(x: dx, y: dy, duration: 0.03))
            moves.append(.moveBy(x: -dx, y: -dy, duration: 0.03))
        }
        cameraNode.run(.sequence(moves), withKey: "shake")
    }
}
