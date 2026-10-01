//
//  OrbitScene.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SpriteKit
import GameplayKit
import UIKit

// The SpriteKit stage. It draws the World and plays each StepEvent as an animation:
// - every move leaves a trail segment tagged with the line of code that made it
// - every trip through a repeat that comes back to its start becomes a glowing orbit ring
// - every if fires a sensor cone so you can see the check happen
// - a crash breaks apart with physics; a win turns your flight path into a constellation

final class OrbitScene: SKScene {
    /// Called with a line number when the player taps part of the rocket's trail.
    var onTrailTapped: ((Int) -> Void)?

    var style = SceneStyle() {
        didSet { if style != oldValue { relayout() } }
    }

    private struct TrailSegment {
        let from: GridPoint
        let to: GridPoint
        let line: Int
        var node: SKShapeNode?
    }

    private struct Ring {
        let points: [GridPoint]
        let iteration: Int
    }

    // The mission as the scene currently shows it.
    private var world: World?
    private var rocketCell = GridPoint(x: 0, y: 0)
    private var heading: Direction = .up
    private var trail: [TrailSegment] = []
    private var rings: [Ring] = []
    private var destroyedAsteroids: Set<GridPoint> = []
    private var highlightedLine: Int?
    private var hintPath: [GridPoint] = []

    // Layout, recalculated whenever the scene changes size.
    private var cellSize: CGFloat = 40
    private var gridOrigin: CGPoint = .zero

    private let cameraNode = SKCameraNode()
    private let backdropLayer = SKNode()
    private let decorLayer = SKNode()
    private let gridLayer = SKNode()
    private let objectLayer = SKNode()
    private let trailLayer = SKNode()
    private let ringLayer = SKNode()
    private let effectLayer = SKNode()
    private let rocket = RocketNode()
    private var asteroidNodes: [GridPoint: SKNode] = [:]
    private var gridBorder: SKShapeNode?
    private var goalNode: SKNode?

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = SceneArt.spaceColor
        physicsWorld.gravity = .zero

        for (depth, layer) in [backdropLayer, decorLayer, gridLayer, objectLayer, trailLayer, ringLayer].enumerated() {
            layer.zPosition = CGFloat(depth)
            addChild(layer)
        }
        rocket.zPosition = 10
        addChild(rocket)
        effectLayer.zPosition = 20
        addChild(effectLayer)
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

    /// Shows a mission's starting state, clearing everything from the last flight.
    func load(_ world: World) {
        self.world = world
        rocketCell = world.rocket
        heading = .up
        trail.removeAll()
        rings.removeAll()
        destroyedAsteroids.removeAll()
        highlightedLine = nil
        hintPath = []
        effectLayer.removeAllChildren()
        rocket.reset(launched: world.isLaunched)
        relayout()
    }

    // MARK: - Layout

    private func point(for cell: GridPoint) -> CGPoint {
        let rows = CGFloat(world?.height ?? 0)
        return CGPoint(x: gridOrigin.x + (CGFloat(cell.x) + 0.5) * cellSize,
                       y: gridOrigin.y + (rows - CGFloat(cell.y) - 0.5) * cellSize)
    }

    /// The corner at the top-left of a square (used for Earth, which sits between squares).
    private func point(forVertex vertex: GridPoint) -> CGPoint {
        let rows = CGFloat(world?.height ?? 0)
        return CGPoint(x: gridOrigin.x + CGFloat(vertex.x) * cellSize,
                       y: gridOrigin.y + (rows - CGFloat(vertex.y)) * cellSize)
    }

    /// Rebuilds every node from the model, so rotating the device keeps everything in place.
    private func relayout() {
        guard size.width > 1, size.height > 1 else { return }
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        buildBackdrop()

        guard let world else { return }
        let padding: CGFloat = 20
        cellSize = floor(min((size.width - padding * 2) / CGFloat(world.width),
                             (size.height - padding * 2) / CGFloat(world.height)))
        cellSize = max(cellSize, 8)
        gridOrigin = CGPoint(x: (size.width - cellSize * CGFloat(world.width)) / 2,
                             y: (size.height - cellSize * CGFloat(world.height)) / 2)

        buildDecor(world)
        buildGrid(world)
        buildObjects(world)
        rebuildTrail()
        rebuildRings()

        rocket.configure(cellSize: cellSize)
        rocket.position = point(for: rocketCell)
        rocket.zRotation = heading.angle
        if !hintPath.isEmpty { drawHint(animated: false) }
    }

    private func buildBackdrop() {
        backdropLayer.removeAllChildren()
        // A fixed seed keeps the stars in the same place every time.
        let random = GKMersenneTwisterRandomSource(seed: 2027)

        let nebulaColors = [UIColor.purple, UIColor.blue, UIColor(red: 0, green: 0.6, blue: 0.7, alpha: 1)]
        for color in nebulaColors {
            let nebula = SceneArt.glow(color: color, diameter: max(size.width, size.height) * 0.8, alpha: 0.13)
            nebula.position = CGPoint(x: size.width * CGFloat(random.nextUniform()), y: size.height * CGFloat(random.nextUniform()))
            backdropLayer.addChild(nebula)
        }

        let count = min(220, max(60, Int(size.width * size.height / 3500)))
        for _ in 0..<count {
            let star = SKSpriteNode(texture: SceneArt.softDot)
            let diameter = CGFloat(2 + random.nextUniform() * 4)
            star.size = CGSize(width: diameter, height: diameter)
            let brightness = CGFloat(0.25 + 0.7 * random.nextUniform())
            star.alpha = brightness
            star.position = CGPoint(x: size.width * CGFloat(random.nextUniform()), y: size.height * CGFloat(random.nextUniform()))
            if !style.reduceMotion && random.nextUniform() < 0.3 {
                let duration = Double(1 + 2 * random.nextUniform())
                star.run(.repeatForever(.sequence([.fadeAlpha(to: 0.1, duration: duration), .fadeAlpha(to: brightness, duration: duration)])))
            }
            backdropLayer.addChild(star)
        }
    }

    private func buildDecor(_ world: World) {
        decorLayer.removeAllChildren()
        goalNode = nil
        let gridWidth = cellSize * CGFloat(world.width)
        let gridHeight = cellSize * CGFloat(world.height)

        if world.launchPad != nil {
            // Earth's horizon curves along the bottom row, so the launch pad sits on the ground.
            let radius = gridWidth * 0.9
            let center = CGPoint(x: size.width / 2, y: gridOrigin.y + cellSize * 0.75 - radius)
            let atmosphere = SceneArt.glow(color: UIColor(red: 0.3, green: 0.7, blue: 1, alpha: 1), diameter: radius * 2.35, alpha: 0.35)
            atmosphere.position = center
            decorLayer.addChild(atmosphere)

            let earth = SKShapeNode(circleOfRadius: radius)
            earth.position = center
            earth.fillColor = UIColor(red: 0.07, green: 0.22, blue: 0.45, alpha: 1)
            earth.strokeColor = UIColor(red: 0.45, green: 0.8, blue: 1, alpha: 0.6)
            earth.lineWidth = 3
            for (x, width) in [(-0.3, 0.5), (0.35, 0.35)] as [(CGFloat, CGFloat)] {
                let land = SKShapeNode(ellipseOf: CGSize(width: radius * width, height: radius * 0.1))
                land.position = CGPoint(x: radius * x, y: radius * 0.82)
                land.fillColor = UIColor(red: 0.25, green: 0.6, blue: 0.35, alpha: 0.9)
                land.strokeColor = .clear
                earth.addChild(land)
            }
            decorLayer.addChild(earth)
        }

        if let vertex = world.planetVertex {
            let planet = SceneArt.planet(cellSize: cellSize, animated: !style.reduceMotion)
            planet.position = point(forVertex: vertex)
            decorLayer.addChild(planet)
        }

        if world.moonRow != nil {
            // The Moon's lower edge covers the top row: reaching that row means landing.
            let radius = gridWidth * 0.6
            let moon = SceneArt.moon(radius: radius)
            moon.position = CGPoint(x: size.width / 2, y: gridOrigin.y + gridHeight - cellSize + radius)
            decorLayer.addChild(moon)
            goalNode = moon
        }
    }

    private func buildGrid(_ world: World) {
        gridLayer.removeAllChildren()
        let rect = CGRect(origin: gridOrigin, size: CGSize(width: cellSize * CGFloat(world.width), height: cellSize * CGFloat(world.height)))

        let path = CGMutablePath()
        for column in 1..<world.width {
            let x = rect.minX + CGFloat(column) * cellSize
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        for row in 1..<world.height {
            let y = rect.minY + CGFloat(row) * cellSize
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        let lines = SKShapeNode(path: path)
        lines.strokeColor = UIColor(white: 1, alpha: style.highContrast ? 0.25 : 0.07)
        lines.lineWidth = 1
        gridLayer.addChild(lines)

        let border = SKShapeNode(rect: rect, cornerRadius: 8)
        border.strokeColor = UIColor(white: 1, alpha: style.highContrast ? 0.6 : 0.18)
        border.lineWidth = 1.5
        border.fillColor = .clear
        gridLayer.addChild(border)
        gridBorder = border
    }

    private func buildObjects(_ world: World) {
        objectLayer.removeAllChildren()
        asteroidNodes = [:]

        if let pad = world.launchPad {
            let node = SceneArt.launchPad(cellSize: cellSize)
            node.position = point(for: pad)
            objectLayer.addChild(node)
        }
        if let station = world.station {
            let node = SceneArt.station(cellSize: cellSize, animated: !style.reduceMotion)
            node.position = point(for: station)
            objectLayer.addChild(node)
            goalNode = node
        }
        for cell in world.asteroids where !destroyedAsteroids.contains(cell) {
            let seed = UInt64(cell.x * 31 + cell.y * 17 + 5)
            let node = SceneArt.asteroid(cellSize: cellSize, seed: seed, animated: !style.reduceMotion)
            node.position = point(for: cell)
            // Static physics bodies, so debris from a crash bounces off nearby rocks.
            let body = SKPhysicsBody(circleOfRadius: cellSize * 0.28)
            body.isDynamic = false
            body.categoryBitMask = 1
            node.physicsBody = body
            objectLayer.addChild(node)
            asteroidNodes[cell] = node
        }
    }

    // MARK: - Trail and rings

    private var trailColor: UIColor {
        style.highContrast ? .white : SceneArt.trailColor
    }

    private func makeSegmentNode(_ segment: TrailSegment) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: point(for: segment.from))
        path.addLine(to: point(for: segment.to))

        let node = SKShapeNode(path: path)
        node.strokeColor = trailColor
        node.lineWidth = max(2.5, cellSize * (style.highContrast ? 0.1 : 0.07))
        node.lineCap = .round

        let glow = SKShapeNode(path: path)
        glow.strokeColor = trailColor.withAlphaComponent(0.18)
        glow.lineWidth = node.lineWidth * 3.5
        glow.lineCap = .round
        glow.zPosition = -0.1
        node.addChild(glow)

        trailLayer.addChild(node)
        return node
    }

    private func rebuildTrail() {
        trailLayer.removeAllChildren()
        for index in trail.indices {
            trail[index].node = makeSegmentNode(trail[index])
        }
        applyTrailHighlight()
    }

    /// Draws one trip through a loop as a ring. Later trips are drawn a little larger,
    /// so the rings stack outward like the rings of a planet.
    private func makeRingNode(_ ring: Ring) -> SKNode {
        let corners = ring.points.dropLast().map { point(for: $0) }
        let center = CGPoint(x: corners.map(\.x).reduce(0, +) / CGFloat(corners.count),
                             y: corners.map(\.y).reduce(0, +) / CGFloat(corners.count))
        let scale = 1 + 0.16 * CGFloat(min(ring.iteration - 1, 6))
        let path = CGMutablePath()
        for (index, corner) in corners.enumerated() {
            let point = CGPoint(x: (corner.x - center.x) * scale, y: (corner.y - center.y) * scale)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()

        let color = SceneArt.ringColors[(ring.iteration - 1) % SceneArt.ringColors.count]
        let node = SKShapeNode(path: path)
        node.position = center
        node.strokeColor = color
        node.lineWidth = max(2, cellSize * 0.05)
        node.lineJoin = .round

        let glow = SKShapeNode(path: path)
        glow.strokeColor = color.withAlphaComponent(0.25)
        glow.lineWidth = node.lineWidth * 4
        glow.lineJoin = .round
        node.addChild(glow)

        ringLayer.addChild(node)
        return node
    }

    private func rebuildRings() {
        ringLayer.removeAllChildren()
        for ring in rings {
            _ = makeRingNode(ring)
        }
    }

    // MARK: - Playing events

    func play(_ event: StepEvent, duration: TimeInterval) {
        clearHint()
        if highlightedLine != nil { highlightTrail(line: nil) }

        switch event.kind {
        case .launched:
            playLaunch(duration: duration)
        case .moved(let from, let to, let direction):
            playMove(from: from, to: to, direction: direction, line: event.line, duration: duration)
        case .sensed(_, let direction, let target, let result):
            playSensor(direction: direction, target: target, detected: result, duration: duration)
        case .loopIterationStarted:
            break
        case .loopIterationEnded(let iteration, _, let path):
            playLoopEnd(iteration: iteration, path: path, duration: duration)
        case .crashed(let at, let from, let direction):
            playCrash(at: at, from: from, direction: direction, duration: duration)
        case .runtimeError:
            playConfused()
        }
    }

    private func playLaunch(duration: TimeInterval) {
        rocket.enter(FlyingState.self)
        rocket.boost(for: duration * 0.7)

        let smoke = SceneArt.burst(colors: [UIColor(white: 0.9, alpha: 1), UIColor(white: 0.5, alpha: 1)],
                                   count: style.reduceMotion ? 30 : 90, speed: cellSize * 1.2, lifetime: 1.2, size: cellSize * 0.5)
        smoke.position = CGPoint(x: rocket.position.x, y: rocket.position.y - cellSize * 0.35)
        effectLayer.addChild(smoke)

        let hop = cellSize * 0.15
        let liftOff = SKAction.moveBy(x: 0, y: hop, duration: duration * 0.35)
        liftOff.timingMode = .easeOut
        let settle = SKAction.moveBy(x: 0, y: -hop, duration: duration * 0.4)
        settle.timingMode = .easeInEaseOut
        rocket.run(.sequence([liftOff, settle]))
        shake(amount: cellSize * 0.05)
    }

    private func playMove(from: GridPoint, to: GridPoint, direction: Direction, line: Int, duration: TimeInterval) {
        heading = direction
        rocketCell = to

        let travel = SKAction.move(to: point(for: to), duration: duration * 0.7)
        travel.timingMode = .easeInEaseOut
        rocket.removeAction(forKey: "move")
        rocket.run(.sequence([.rotate(toAngle: direction.angle, duration: duration * 0.2, shortestUnitArc: true), travel]), withKey: "move")

        var segment = TrailSegment(from: from, to: to, line: line)
        let node = makeSegmentNode(segment)
        node.alpha = 0
        node.run(.sequence([.wait(forDuration: duration * 0.2), .fadeIn(withDuration: duration * 0.7)]))
        segment.node = node
        trail.append(segment)
    }

    private func playSensor(direction: Direction, target: GridPoint, detected: Bool, duration: TimeInterval) {
        heading = direction
        rocket.run(.rotate(toAngle: direction.angle, duration: duration * 0.15, shortestUnitArc: true))

        let alert = style.colorBlind ? UIColor.orange : UIColor.systemRed
        let clear = style.colorBlind ? UIColor.cyan : UIColor.systemGreen
        let color = detected ? alert : clear

        // A cone that widens from the rocket's nose across the square it's checking.
        let origin = point(for: rocketCell)
        let tip = point(for: target)
        let dx = tip.x - origin.x, dy = tip.y - origin.y
        let length = max(hypot(dx, dy), 1)
        let spread = CGPoint(x: -dy / length * cellSize * 0.45, y: dx / length * cellSize * 0.45)
        let start = CGPoint(x: origin.x + dx * 0.3, y: origin.y + dy * 0.3)
        let farEnd = CGPoint(x: origin.x + dx * 1.45, y: origin.y + dy * 1.45)
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: CGPoint(x: farEnd.x + spread.x, y: farEnd.y + spread.y))
        path.addLine(to: CGPoint(x: farEnd.x - spread.x, y: farEnd.y - spread.y))
        path.closeSubpath()

        let cone = SKShapeNode(path: path)
        cone.fillColor = color.withAlphaComponent(0.28)
        cone.strokeColor = color.withAlphaComponent(0.8)
        cone.lineWidth = 1.5
        cone.alpha = 0
        cone.run(.sequence([.fadeIn(withDuration: 0.12), .wait(forDuration: duration * 0.55), .fadeOut(withDuration: 0.25), .removeFromParent()]))
        effectLayer.addChild(cone)

        let ping = SKShapeNode(circleOfRadius: cellSize * 0.2)
        ping.position = tip
        ping.strokeColor = color
        ping.lineWidth = 2
        ping.run(.sequence([.group([.scale(to: 2.4, duration: duration * 0.6), .fadeOut(withDuration: duration * 0.6)]), .removeFromParent()]))
        effectLayer.addChild(ping)

        if detected, let asteroid = asteroidNodes[target] {
            asteroid.run(.sequence([.scale(to: 1.2, duration: 0.1), .scale(to: 1, duration: 0.2)]))
        }
    }

    private func playLoopEnd(iteration: Int, path: [GridPoint], duration: TimeInterval) {
        guard path.count > 1 else { return }

        if path.first == path.last, path.count >= 4 {
            // The loop brought the rocket back where it started: an orbit.
            let ring = Ring(points: path, iteration: iteration)
            rings.append(ring)
            let node = makeRingNode(ring)
            node.alpha = 0
            node.setScale(0.8)
            let grow = SKAction.scale(to: 1, duration: duration * 0.7)
            grow.timingMode = .easeOut
            node.run(.group([.fadeIn(withDuration: duration * 0.7), grow]))
        } else {
            // An open loop (like flying upward) gets a quick glow along that trip instead.
            let line = CGMutablePath()
            for (index, cell) in path.enumerated() {
                index == 0 ? line.move(to: point(for: cell)) : line.addLine(to: point(for: cell))
            }
            let flash = SKShapeNode(path: line)
            flash.strokeColor = SceneArt.ringColors[(iteration - 1) % SceneArt.ringColors.count].withAlphaComponent(0.7)
            flash.lineWidth = cellSize * 0.14
            flash.lineCap = .round
            flash.lineJoin = .round
            flash.run(.sequence([.fadeOut(withDuration: duration * 1.2), .removeFromParent()]))
            effectLayer.addChild(flash)
        }
    }

    private func playCrash(at cell: GridPoint, from: GridPoint, direction: Direction, duration: TimeInterval) {
        heading = direction
        let start = point(for: from)
        let rock = point(for: cell)
        let impact = CGPoint(x: start.x + (rock.x - start.x) * 0.55, y: start.y + (rock.y - start.y) * 0.55)

        let approach = SKAction.move(to: impact, duration: duration * 0.3)
        approach.timingMode = .easeIn
        rocket.run(.sequence([
            .rotate(toAngle: direction.angle, duration: duration * 0.12, shortestUnitArc: true),
            approach,
            .run { [weak self] in self?.explode(at: impact, asteroid: cell) }
        ]), withKey: "move")
    }

    private func explode(at position: CGPoint, asteroid cell: GridPoint) {
        rocket.enter(CrashedState.self)
        destroyedAsteroids.insert(cell)
        asteroidNodes[cell]?.run(.sequence([.group([.scale(to: 1.4, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        asteroidNodes[cell] = nil

        let fire = SceneArt.burst(colors: [.white, .yellow, .orange, .red], count: style.reduceMotion ? 40 : 120,
                                  speed: cellSize * 2.5, lifetime: 0.8, size: cellSize * 0.35)
        fire.position = position
        effectLayer.addChild(fire)

        // Debris: real physics bodies that tumble away and bounce off other asteroids.
        let pieceColors = [UIColor.white, UIColor(red: 0.95, green: 0.3, blue: 0.3, alpha: 1), UIColor(red: 0.42, green: 0.38, blue: 0.36, alpha: 1)]
        for index in 0..<(style.reduceMotion ? 6 : 14) {
            let size = cellSize * CGFloat.random(in: 0.05...0.11)
            let shard = UIBezierPath()
            shard.move(to: CGPoint(x: -size, y: -size * 0.6))
            shard.addLine(to: CGPoint(x: size, y: -size * 0.4))
            shard.addLine(to: CGPoint(x: 0, y: size))
            shard.close()
            let piece = SKShapeNode(path: shard.cgPath)
            piece.fillColor = pieceColors[index % pieceColors.count]
            piece.strokeColor = .clear
            piece.position = position

            let body = SKPhysicsBody(circleOfRadius: size * 0.6)
            body.categoryBitMask = 2
            body.collisionBitMask = 1
            body.linearDamping = 1.2
            body.angularDamping = 0.4
            body.restitution = 0.6
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = cellSize * CGFloat.random(in: 2...5)
            body.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
            body.angularVelocity = CGFloat.random(in: -12...12)
            piece.physicsBody = body
            piece.run(.sequence([.wait(forDuration: 0.8), .fadeOut(withDuration: 0.8), .removeFromParent()]))
            effectLayer.addChild(piece)
        }
        shake(amount: cellSize * 0.12)
    }

    /// The rocket wobbles and the mission border flashes when code asks for something impossible.
    private func playConfused() {
        rocket.run(.sequence([
            .rotate(byAngle: 0.2, duration: 0.08),
            .rotate(byAngle: -0.4, duration: 0.12),
            .rotate(byAngle: 0.4, duration: 0.12),
            .rotate(byAngle: -0.2, duration: 0.08)
        ]))
        guard let border = gridBorder else { return }
        let normal = border.strokeColor
        border.strokeColor = .systemRed
        border.run(.sequence([.wait(forDuration: 0.6), .run { [weak border] in border?.strokeColor = normal }]))
    }

    // MARK: - Winning

    /// Turns every point the rocket visited into a star, and the trail into constellation lines.
    func celebrate() {
        rocket.enter(DockedState.self)

        var points: [GridPoint] = []
        if let first = trail.first { points.append(first.from) }
        for segment in trail where points.last != segment.to { points.append(segment.to) }
        if points.isEmpty { points = [rocketCell] }
        var seen = Set<GridPoint>()
        points = points.filter { seen.insert($0).inserted }

        for (index, cell) in points.enumerated() {
            let star = SKLabelNode(text: "✦")
            star.fontSize = cellSize * 0.42
            star.fontColor = .white
            star.verticalAlignmentMode = .center
            star.position = point(for: cell)
            star.setScale(0)
            let appear = SKAction.scale(to: 1, duration: 0.25)
            appear.timingMode = .easeOut
            star.run(.sequence([.wait(forDuration: Double(index) * 0.06), appear]))
            effectLayer.addChild(star)

            let halo = SceneArt.glow(color: SceneArt.guideGold, diameter: cellSize * 0.8, alpha: 0)
            halo.position = star.position
            halo.run(.sequence([.wait(forDuration: Double(index) * 0.06), .fadeAlpha(to: 0.6, duration: 0.3)]))
            effectLayer.addChild(halo)
        }

        for segment in trail {
            guard let node = segment.node else { continue }
            node.run(.sequence([.wait(forDuration: Double(points.count) * 0.06), .run { [weak node] in
                node?.strokeColor = UIColor(white: 1, alpha: 0.55)
            }]))
        }

        let sparkles = SceneArt.burst(colors: [SceneArt.guideGold, .white], count: style.reduceMotion ? 30 : 90,
                                      speed: cellSize * 1.8, lifetime: 1.2, size: cellSize * 0.25)
        sparkles.position = rocket.position
        effectLayer.addChild(sparkles)

        if !style.reduceMotion {
            goalNode?.run(.sequence([.scale(to: 1.08, duration: 0.25), .scale(to: 1, duration: 0.35)]))
        }
    }

    // MARK: - Hints and highlighting

    /// Draws a dotted route for the Guiding Light's hint.
    func showHint(_ path: [GridPoint]) {
        hintPath = path
        drawHint(animated: true)
    }

    private func drawHint(animated: Bool) {
        effectLayer.childNode(withName: "hint")?.removeFromParent()
        guard hintPath.count > 1 else { return }

        let line = CGMutablePath()
        for (index, cell) in hintPath.enumerated() {
            index == 0 ? line.move(to: point(for: cell)) : line.addLine(to: point(for: cell))
        }
        let node = SKShapeNode(path: line.copy(dashingWithPhase: 0, lengths: [6, 6]))
        node.name = "hint"
        node.strokeColor = SceneArt.guideGold.withAlphaComponent(0.85)
        node.lineWidth = 2.5
        node.lineCap = .round
        effectLayer.addChild(node)
        if animated {
            node.alpha = 0
            node.run(.fadeIn(withDuration: 0.4))
        }
    }

    private func clearHint() {
        hintPath = []
        effectLayer.childNode(withName: "hint")?.removeFromParent()
    }

    /// Highlights every trail segment made by one line of code, and labels it.
    func highlightTrail(line: Int?) {
        highlightedLine = line
        applyTrailHighlight()
    }

    private func applyTrailHighlight() {
        trailLayer.children.filter { $0.name == "lineTag" }.forEach { $0.removeFromParent() }
        var labeled = Set<GridPoint>()
        for segment in trail {
            guard let node = segment.node else { continue }
            guard let line = highlightedLine else {
                node.strokeColor = trailColor
                node.alpha = 1
                continue
            }
            if segment.line == line {
                node.strokeColor = .systemYellow
                node.alpha = 1
                // Label each highlighted segment once, at its midpoint.
                if labeled.insert(segment.to).inserted {
                    let start = point(for: segment.from), end = point(for: segment.to)
                    let tag = SKLabelNode(text: "\(line)")
                    tag.name = "lineTag"
                    tag.fontName = "AvenirNext-Bold"
                    tag.fontSize = max(11, cellSize * 0.24)
                    tag.fontColor = .black
                    tag.verticalAlignmentMode = .center
                    let badge = SKShapeNode(circleOfRadius: max(9, cellSize * 0.17))
                    badge.fillColor = .systemYellow
                    badge.strokeColor = .clear
                    badge.zPosition = -1
                    tag.addChild(badge)
                    tag.position = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                    tag.zPosition = 2
                    trailLayer.addChild(tag)
                }
            } else {
                node.strokeColor = trailColor
                node.alpha = 0.25
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        var closest: (line: Int, distance: CGFloat)?
        for segment in trail {
            let distance = Self.distance(from: location, toSegment: point(for: segment.from), point(for: segment.to))
            if distance < cellSize * 0.4 && distance < (closest?.distance ?? .infinity) {
                closest = (segment.line, distance)
            }
        }
        if let closest {
            onTrailTapped?(closest.line)
        } else if let highlightedLine {
            // Tapping empty space clears the highlight.
            onTrailTapped?(highlightedLine)
        }
    }

    private static func distance(from point: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(point.x - a.x, point.y - a.y) }
        let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
        return hypot(point.x - (a.x + t * dx), point.y - (a.y + t * dy))
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
