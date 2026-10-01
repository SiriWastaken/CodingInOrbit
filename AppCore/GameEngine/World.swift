//
//  World.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import Foundation
import GameplayKit

// The World is the "truth" of a mission: a grid of squares, the rocket, and what's around it.
// It's plain Swift with no animation or physics, so the same code always gives the same
// result. SpriteKit only draws what happens here; it never decides whether code succeeded.

struct GridPoint: Hashable, Sendable {
    var x: Int
    var y: Int

    func moved(_ direction: Direction) -> GridPoint {
        GridPoint(x: x + direction.delta.dx, y: y + direction.delta.dy)
    }
}

struct World: Equatable, Sendable {
    let width: Int
    let height: Int
    var rocket: GridPoint
    var heading: Direction = .up
    var isLaunched: Bool
    var launchPad: GridPoint?
    var station: GridPoint?
    /// Earth sits on the corner where 4 squares meet, so a 4-move loop flies around it.
    var planetVertex: GridPoint?
    /// The row the Moon sits on. Reaching it means landing.
    var moonRow: Int?
    var asteroids: Set<GridPoint> = []

    func contains(_ point: GridPoint) -> Bool {
        (0..<width).contains(point.x) && (0..<height).contains(point.y)
    }

    /// Reads a sensor. The rocket scans the square in front of it.
    func sense(_ condition: Condition) -> (target: GridPoint, result: Bool) {
        switch condition {
        case .asteroidAhead:
            let target = rocket.moved(heading)
            return (target, asteroids.contains(target))
        }
    }

    /// The shortest safe route to the nearest goal, found with GameplayKit's grid pathfinding.
    /// The Guiding Light uses it to draw hints.
    func shortestPath(to goals: [GridPoint]) -> [GridPoint] {
        let graph = GKGridGraph<GKGridGraphNode>(
            fromGridStartingAt: vector_int2(0, 0),
            width: Int32(width),
            height: Int32(height),
            diagonalsAllowed: false
        )
        let blocked = asteroids.compactMap { graph.node(atGridPosition: $0.vector) }
        graph.remove(blocked)

        guard let start = graph.node(atGridPosition: rocket.vector) else { return [] }
        var best: [GridPoint] = []
        for goal in goals {
            guard let end = graph.node(atGridPosition: goal.vector) else { continue }
            let nodes = graph.findPath(from: start, to: end).compactMap { $0 as? GKGridGraphNode }
            if !nodes.isEmpty && (best.isEmpty || nodes.count < best.count) {
                best = nodes.map { GridPoint(x: Int($0.gridPosition.x), y: Int($0.gridPosition.y)) }
            }
        }
        return best
    }

    /// Describes the scene in words, for VoiceOver.
    func spokenDescription(rocketAt position: GridPoint, launched: Bool) -> String {
        var parts = ["Rocket in column \(position.x + 1), row \(height - position.y) from the bottom, \(launched ? "flying" : "on the launch pad")."]
        if let station {
            parts.append("The space station is \(Self.offsetPhrase(from: position, to: station)).")
        }
        if let moonRow, position.y != moonRow {
            let rows = position.y - moonRow
            parts.append("The Moon is \(rows) \(rows == 1 ? "row" : "rows") up.")
        }
        if let planetVertex {
            let horizontal = planetVertex.x > position.x ? "right" : "left"
            let vertical = planetVertex.y > position.y ? "below" : "above"
            parts.append("Earth is \(vertical) and to the \(horizontal).")
        }
        if !asteroids.isEmpty {
            parts.append("\(asteroids.count) \(asteroids.count == 1 ? "asteroid" : "asteroids") nearby.")
        }
        return parts.joined(separator: " ")
    }

    /// "2 squares right and 3 squares up"
    static func offsetPhrase(from start: GridPoint, to end: GridPoint) -> String {
        let dx = end.x - start.x
        let dy = start.y - end.y
        var parts: [String] = []
        if dx != 0 { parts.append("\(abs(dx)) \(abs(dx) == 1 ? "square" : "squares") \(dx > 0 ? "right" : "left")") }
        if dy != 0 { parts.append("\(abs(dy)) \(abs(dy) == 1 ? "square" : "squares") \(dy > 0 ? "up" : "down")") }
        return parts.isEmpty ? "right here" : parts.joined(separator: " and ")
    }
}

extension GridPoint {
    var vector: vector_int2 { vector_int2(Int32(x), Int32(y)) }
}
