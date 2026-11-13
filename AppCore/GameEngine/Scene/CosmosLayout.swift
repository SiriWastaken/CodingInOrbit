//
//  CosmosLayout.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-10-01.
//

import CoreGraphics
import Foundation

// Players never type coordinates. The universe arranges itself: this file decides where
// everything sits, given what exists. Each time something new is made, everything else
// shifts over to make room, so the world visibly grows with the code.
//
// It's pure math with no SpriteKit, so the arrangement is easy to reason about.
// Positions are in scene points, with the origin at the bottom left.

struct Orbit: Equatable {
    var center: CGPoint
    var radius: CGFloat
    /// Seconds for one trip around.
    var period: Double
    /// Where on the circle it starts, in radians.
    var phase: Double

    func position(at time: Double) -> CGPoint {
        let angle = phase + time / period * 2 * .pi
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}

struct Placement: Equatable {
    var position: CGPoint
    /// How big it is on screen: a rocket's height, a planet's diameter, a pad's width.
    var size: CGFloat
    var orbit: Orbit?
    /// Tilt, so things on the Moon's curved ground lean with it.
    var rotation: CGFloat = 0
}

struct CosmosLayout {
    var placements: [Int: Placement] = [:]
    /// Planet centers and radii, which bend the fabric of space around them.
    var masses: [(center: CGPoint, strength: CGFloat)] = []
    /// The Moon's ground: a huge circle whose top edge is the surface.
    var ground: (center: CGPoint, radius: CGFloat)?
    var unit: CGFloat = 1

    /// The height of the lunar surface at a given x.
    func surface(at x: CGFloat) -> CGFloat {
        guard let ground else { return 0 }
        let dx = min(abs(x - ground.center.x), ground.radius * 0.99)
        return ground.center.y + sqrt(ground.radius * ground.radius - dx * dx)
    }

    func tilt(at x: CGFloat) -> CGFloat {
        guard let ground else { return 0 }
        let dx = x - ground.center.x
        let height = max(surface(at: x) - ground.center.y, 1)
        return -atan(dx / height)
    }

    // MARK: - Arranging

    static func arrange(_ world: World, in size: CGSize) -> CosmosLayout {
        let w = size.width, h = size.height
        var layout = CosmosLayout()
        layout.unit = min(w, h)

        switch world.stage {
        case .launchSite: layout.arrangeLaunchSite(world, w: w, h: h)
        case .orbit: layout.arrangeOrbit(world, w: w, h: h)
        case .moon: layout.arrangeMoon(world, w: w, h: h)
        }
        layout.arrangeBackground(world, w: w, h: h)
        return layout
    }

    /// Stars, asteroids, and comets drift in the background of every stage.
    private mutating func arrangeBackground(_ world: World, w: CGFloat, h: CGFloat) {
        let u = unit
        if let star = world.bodies(of: .star).first {
            switch world.stage {
            case .launchSite:
                placements[star.id] = Placement(position: CGPoint(x: w * 0.15, y: h * 0.84), size: u * 0.16)
            case .orbit:
                // A giant sun glowing at the edge, with everything else orbiting in its light.
                placements[star.id] = Placement(position: CGPoint(x: -u * 0.04, y: h * 0.5), size: u * 0.26)
                masses.append((CGPoint(x: -u * 0.04, y: h * 0.5), 1.3))
            case .moon:
                placements[star.id] = Placement(position: CGPoint(x: w * 0.87, y: h * 0.85), size: u * 0.13)
            }
        }
        for (index, asteroid) in world.bodies(of: .asteroid).enumerated() {
            let fraction = (0.618 * Double(index) + 0.23).truncatingRemainder(dividingBy: 1)
            let position = CGPoint(x: w * (0.2 + 0.62 * CGFloat(fraction)), y: h * (0.915 - 0.045 * CGFloat(index % 3)))
            placements[asteroid.id] = Placement(position: position, size: u * (0.07 + 0.012 * CGFloat(index % 3)))
        }
        for (index, comet) in world.bodies(of: .comet).enumerated() {
            let position = CGPoint(x: w * (0.78 - 0.17 * CGFloat(index)), y: h * (0.8 - 0.08 * CGFloat(index)))
            placements[comet.id] = Placement(position: position, size: u * 0.1)
        }
    }

    // MARK: Launch site

    private mutating func arrangeLaunchSite(_ world: World, w: CGFloat, h: CGFloat) {
        struct Unit { var pad: Body?; var rocket: Body?; var order: Int }
        let pads = world.bodies(of: .launchpad)
        var units: [Unit] = pads.map { pad in
            Unit(pad: pad, rocket: world.rockets.first { $0.host == pad.id }, order: pad.id)
        }
        for rocket in world.rockets where !pads.contains(where: { $0.id == rocket.host }) {
            units.append(Unit(pad: nil, rocket: rocket, order: rocket.id))
        }
        units.sort { $0.order < $1.order }
        guard !units.isEmpty else { return }

        let spacing = w / CGFloat(units.count + 1)
        let padWidth = min(unit * 0.36, spacing * 0.82)
        let padSurface = h * 0.2
        for (index, item) in units.enumerated() {
            let x = spacing * CGFloat(index + 1)
            if let pad = item.pad {
                placements[pad.id] = Placement(position: CGPoint(x: x, y: padSurface), size: padWidth)
            }
            if let rocket = item.rocket {
                let rocketHeight = padWidth * 0.7
                let shift = CGPoint(x: CGFloat(rocket.shiftX) * unit * 0.08, y: CGFloat(rocket.shiftY) * unit * 0.08)
                let y: CGFloat
                switch rocket.flight {
                case .grounded:
                    y = item.pad != nil ? padSurface + padWidth * 0.05 + rocketHeight / 2 : h * 0.42
                case .flying, .orbiting, .landed:
                    y = h * 0.64
                }
                placements[rocket.id] = Placement(position: CGPoint(x: x + shift.x, y: y + shift.y), size: rocketHeight)
            }
        }
    }

    // MARK: Orbit

    private mutating func arrangeOrbit(_ world: World, w: CGFloat, h: CGFloat) {
        let planets = world.planets
        let hasStar = world.has(.star)
        let regionStart = hasStar ? w * 0.34 : w * 0.24
        let regionEnd = w * 0.9
        let columns = max(planets.count, 1)
        let columnWidth = (regionEnd - regionStart) / CGFloat(columns)

        // Planets shrink as more arrive, so everything and its orbits always fit.
        let byHeight = planets.count > 1 ? h * 0.115 : h * 0.15
        let byWidth = columnWidth / (2 * 3.4) * (planets.count > 1 ? 1.5 : 1)
        let radius = max(min(byHeight, byWidth, w * 0.1), 10)

        for (index, planet) in planets.enumerated() {
            let x = regionStart + columnWidth * (CGFloat(index) + 0.5)
            let y = planets.count > 1 ? h * (index % 2 == 0 ? 0.6 : 0.4) : h * 0.5
            let center = CGPoint(x: x, y: y)
            placements[planet.id] = Placement(position: center, size: radius * 2)
            masses.append((center, 1))

            let moons = world.bodies.filter { $0.thing == .moon && $0.host == planet.id }
            for (k, moon) in moons.enumerated() {
                let orbit = Orbit(center: center, radius: radius * (1.95 + 0.5 * CGFloat(k)), period: 18 + Double(k) * 6,
                                  phase: 0.9 + Double(k) * 2.1 + Double(planet.id))
                placements[moon.id] = Placement(position: orbit.position(at: 0), size: radius * 0.5, orbit: orbit)
            }
            let satellites = world.bodies.filter { $0.thing == .satellite && $0.host == planet.id }
            for (k, satellite) in satellites.enumerated() {
                // Satellites share a few close rings, spaced evenly around so they never bunch up.
                let orbit = Orbit(center: center, radius: radius * (1.38 + 0.15 * CGFloat(k % 3)), period: 5.5 + Double(k % 3) * 1.2,
                                  phase: Double(k) * 2 * .pi / Double(max(satellites.count, 1)) + Double(planet.id))
                placements[satellite.id] = Placement(position: orbit.position(at: 0), size: radius * 0.34, orbit: orbit)
            }
        }

        var hovering = 0
        for rocket in world.rockets {
            let shift = CGPoint(x: CGFloat(rocket.shiftX) * unit * 0.08, y: CGFloat(rocket.shiftY) * unit * 0.08)
            if case .orbiting(let hostID) = rocket.flight, let host = placements[hostID] {
                let orbit = Orbit(center: host.position, radius: host.size / 2 * 3.1, period: 9,
                                  phase: -.pi * 0.6 + Double(hovering) * 2.5)
                hovering += 1
                placements[rocket.id] = Placement(position: orbit.position(at: 0), size: unit * 0.075, orbit: orbit)
            } else {
                let base = CGPoint(x: w * 0.1 + w * 0.07 * CGFloat(hovering), y: h * 0.2)
                hovering += 1
                placements[rocket.id] = Placement(position: CGPoint(x: base.x + shift.x, y: base.y + shift.y), size: unit * 0.15)
            }
        }
    }

    // MARK: Moon

    private mutating func arrangeMoon(_ world: World, w: CGFloat, h: CGFloat) {
        let u = unit
        let hasMoon = world.has(.moon)
        if hasMoon {
            let radius = w * 1.7
            ground = (CGPoint(x: w / 2, y: h * 0.25 - radius), radius)
            masses.append((CGPoint(x: w / 2, y: h * 0.12), 1.6))
        }

        let rocketHeight = u * 0.18
        for (index, rocket) in world.rockets.enumerated() {
            let shift = CGPoint(x: CGFloat(rocket.shiftX) * u * 0.08, y: CGFloat(rocket.shiftY) * u * 0.08)
            let x = w * (0.16 + 0.09 * CGFloat(index))
            if rocket.flight == .landed, hasMoon {
                placements[rocket.id] = Placement(position: CGPoint(x: x, y: surface(at: x) + rocketHeight * 0.5), size: rocketHeight, rotation: tilt(at: x))
            } else {
                placements[rocket.id] = Placement(position: CGPoint(x: x + shift.x, y: h * 0.66 + shift.y), size: rocketHeight)
            }
        }
        guard hasMoon else { return }

        let bases = world.bodies(of: .base)
        let baseSpacing = (w * 0.9 - w * 0.5) / CGFloat(max(bases.count, 1))
        let baseSize = min(u * 0.26, baseSpacing * 0.85)
        var baseX: [CGFloat] = []
        for (index, base) in bases.enumerated() {
            let x = w * 0.5 + baseSpacing * (CGFloat(index) + 0.5)
            baseX.append(x)
            placements[base.id] = Placement(position: CGPoint(x: x, y: surface(at: x)), size: baseSize, rotation: tilt(at: x))
        }

        let roverSize = u * 0.17
        for (index, rover) in world.bodies(of: .rover).enumerated() {
            let x: CGFloat
            if rover.explored, !baseX.isEmpty {
                // After exploring, the rover has driven up beside a base.
                x = baseX[index % baseX.count] - baseSize * 0.62 - CGFloat(index / max(baseX.count, 1)) * roverSize * 0.9
            } else {
                x = w * 0.31 + roverSize * 1.15 * CGFloat(index)
            }
            placements[rover.id] = Placement(position: CGPoint(x: x, y: surface(at: x)), size: roverSize, rotation: tilt(at: x))
        }
    }
}
