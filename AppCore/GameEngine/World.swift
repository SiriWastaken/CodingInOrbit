//
//  World.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import Foundation

// The World is the "truth" of a mission: a list of everything the player's code has made.
// It's plain Swift with no animation or physics, so the same code always gives the same
// universe. SpriteKit only draws what happens here; it never decides whether code succeeded.
//
// Things depend on each other, and those dependencies are where the learning hides:
// a moon needs a planet to circle, a rover needs a moon to roll on, and launch needs
// something to launch.

/// Which corner of space a mission takes place in. It decides what can exist there
/// and how the scene arranges it.
enum Stage: String, Sendable, Codable {
    case launchSite, orbit, moon

    var allowed: [Thing] {
        switch self {
        case .launchSite: [.launchpad, .rocket, .star, .asteroid, .comet]
        case .orbit: [.planet, .moon, .satellite, .rocket, .star, .asteroid, .comet]
        case .moon: [.moon, .rover, .base, .rocket, .star, .asteroid, .comet]
        }
    }
}

/// What a rocket is up to.
enum Flight: Equatable, Sendable {
    case grounded
    case flying
    case orbiting(planet: Int)
    case landed
}

struct Body: Identifiable, Equatable, Sendable {
    let id: Int
    let thing: Thing
    /// What this thing belongs to: a moon's or satellite's planet, or the launchpad a rocket sits on.
    var host: Int?
    /// Rockets only.
    var flight: Flight = .grounded
    /// Which way the rocket points. `move` turns it before it goes.
    var facing: Direction = .up
    /// How far `move` has bent this rocket away from its spot, in steps.
    var shiftX = 0
    var shiftY = 0
    /// Rovers and bases that explore has visited.
    var explored = false
    /// A launchpad that launch built by itself because the rocket had none.
    var autoBuilt = false

    var isRocket: Bool { thing == .rocket }
    var isFlying: Bool {
        switch flight {
        case .flying, .orbiting: true
        case .grounded, .landed: false
        }
    }
}

struct World: Equatable, Sendable {
    let stage: Stage
    private(set) var bodies: [Body] = []
    private var nextID = 1

    init(stage: Stage) {
        self.stage = stage
    }

    // MARK: - Looking

    func bodies(of thing: Thing) -> [Body] { bodies.filter { $0.thing == thing } }
    func count(of thing: Thing) -> Int { bodies.count { $0.thing == thing } }
    func has(_ thing: Thing) -> Bool { bodies.contains { $0.thing == thing } }
    func body(_ id: Int) -> Body? { bodies.first { $0.id == id } }

    var rockets: [Body] { bodies(of: .rocket) }
    var planets: [Body] { bodies(of: .planet) }

    /// Reads the universe for `if`. True when the thing exists (or doesn't, for `not`).
    func sense(_ condition: Condition) -> Bool {
        has(condition.thing) != condition.negated
    }

    private func guests(of host: Int, _ thing: Thing) -> Int {
        bodies.count { $0.thing == thing && $0.host == host }
    }

    // MARK: - Limits

    /// How many of a thing can exist at once. The scene has to stay readable.
    static func limit(for thing: Thing) -> Int {
        switch thing {
        case .launchpad, .rocket, .planet: 4
        case .star: 1
        case .moon: 6
        case .satellite: 10
        case .asteroid: 6
        case .comet: 3
        case .rover, .base: 3
        }
    }

    // MARK: - Creating

    /// Makes something exist, if the universe has room and everything it needs.
    @discardableResult
    mutating func make(_ thing: Thing, line: Int) throws(CodeError) -> Body {
        guard stage.allowed.contains(thing) else {
            let choices = stage.allowed.map(\.rawValue).joined(separator: ", ")
            throw CodeError(line: line, "\(thing.withArticle.capitalizedFirst) doesn't belong in this corner of space.",
                            hint: "Here you can make: \(choices).")
        }

        let capacity = Self.limit(for: thing)
        guard count(of: thing) < capacity else {
            throw CodeError(line: line, "That's plenty of \(thing.plural)! There's only room for \(capacity).",
                            hint: "The universe is getting full. Try making something different.")
        }

        var body = Body(id: nextID, thing: thing)

        switch thing {
        case .star where has(.star):
            throw CodeError(line: line, "There's already a star here. One sun is plenty!",
                            hint: "Planets make great company, though. Try create planet.")

        case .moon where stage == .orbit:
            guard !planets.isEmpty else {
                throw CodeError(line: line, "A moon needs something to circle.",
                                hint: "Make a planet first: create planet.")
            }
            guard let host = planets.reversed().first(where: { guests(of: $0.id, .moon) < 3 }) else {
                throw CodeError(line: line, "Every planet already has all the moons it can hold.",
                                hint: "Maybe a new planet needs one: create planet.")
            }
            body.host = host.id

        case .moon where has(.moon):
            throw CodeError(line: line, "There's already a moon here!",
                            hint: "Two moons would be a lot. You could check first: if not moon: create moon")

        case .satellite:
            guard !planets.isEmpty else {
                throw CodeError(line: line, "A satellite needs a planet to circle.",
                                hint: "Make one first: create planet.")
            }
            guard let host = planets.reversed().first(where: { guests(of: $0.id, .satellite) < 8 }) else {
                throw CodeError(line: line, "That planet is wearing every satellite it can.",
                                hint: "A new planet would love some, though.")
            }
            body.host = host.id

        case .rover, .base:
            guard has(.moon) else {
                throw CodeError(line: line, "\(thing.withArticle.capitalizedFirst) needs ground to stand on.",
                                hint: "Make the moon first: create moon.")
            }

        case .launchpad:
            // The pad slides in beneath a rocket that's waiting without one.
            if let waiting = rockets.first(where: { $0.flight == .grounded && $0.host == nil }) {
                setHost(of: waiting.id, to: nextID)
            }

        case .rocket:
            if stage == .launchSite {
                body.host = bodies(of: .launchpad).first { pad in !rockets.contains { $0.host == pad.id } }?.id
            } else {
                // Away from the launch site, new rockets are already in flight.
                body.flight = .flying
            }

        default:
            break
        }

        nextID += 1
        bodies.append(body)
        return body
    }

    /// How close a rocket has to come (in steps down toward the surface) before it can land.
    static let landingDistance = -2

    /// Sets the rocket down on the Moon, but only once it's come close enough.
    mutating func land(line: Int) throws(CodeError) -> [Int] {
        guard stage == .moon, has(.moon) else {
            throw CodeError(line: line, "There's nowhere to land up here.", hint: "Save land for the moon.")
        }
        let flying = rockets.filter(\.isFlying)
        guard !flying.isEmpty else {
            throw CodeError(line: line, "The rocket isn't flying.", hint: "Every flight starts with launch.")
        }
        guard flying.contains(where: { $0.shiftY <= Self.landingDistance }) else {
            throw CodeError(line: line, "Not yet. You need to get closer to the moon first.")
        }
        return landRockets()
    }

    /// Sets every flying rocket down where it is.
    mutating func landRockets() -> [Int] {
        var landed: [Int] = []
        for index in bodies.indices where bodies[index].isRocket && bodies[index].isFlying {
            bodies[index].flight = .landed
            bodies[index].shiftX = 0
            bodies[index].shiftY = 0
            bodies[index].facing = .up
            landed.append(bodies[index].id)
        }
        return landed
    }

    mutating func setFlight(id: Int, _ flight: Flight) {
        guard let index = bodies.firstIndex(where: { $0.id == id }) else { return }
        bodies[index].flight = flight
    }

    private mutating func setHost(of id: Int, to host: Int?) {
        guard let index = bodies.firstIndex(where: { $0.id == id }) else { return }
        bodies[index].host = host
    }

    /// What would the universe look like with one more of this thing? Nil if it can't be made.
    /// The Guiding Light uses this to draw ghosts for hints and for `if` checks.
    func preview(_ thing: Thing) -> World? {
        var copy = self
        guard (try? copy.make(thing, line: 0)) != nil else { return nil }
        return copy
    }

    // MARK: - Doing

    struct Liftoff {
        var rockets: [Int]
        var builtPads: [Body]
    }

    /// Launches every rocket on the ground. A rocket without a pad gets one built beneath it.
    mutating func launchAll(line: Int) throws(CodeError) -> Liftoff {
        let grounded = rockets.filter { $0.flight == .grounded }
        guard !grounded.isEmpty else {
            if rockets.isEmpty {
                throw CodeError(line: line, "There's nothing to launch yet.",
                                hint: "Rockets don't appear by wishing. Try create rocket first.")
            }
            throw CodeError(line: line, "Everything's already up here!",
                            hint: "launch works on rockets that are still on the ground.")
        }

        var builtPads: [Body] = []
        for rocket in grounded where rocket.host == nil {
            if stage != .launchSite { break }
            guard count(of: .launchpad) < Self.limit(for: .launchpad) else { continue }
            var pad = Body(id: nextID, thing: .launchpad)
            pad.autoBuilt = true
            nextID += 1
            bodies.append(pad)
            setHost(of: rocket.id, to: pad.id)
            builtPads.append(pad)
        }

        for rocket in grounded {
            guard let index = bodies.firstIndex(where: { $0.id == rocket.id }) else { continue }
            bodies[index].flight = .flying
        }
        return Liftoff(rockets: grounded.map(\.id), builtPads: builtPads)
    }

    struct Orbit {
        var planet: Body
        var rockets: [Int]
        var createdPlanet: Bool
    }

    /// Puts every flying rocket into orbit around the newest planet. If there's no planet
    /// to circle, orbit makes one: you can't orbit nothing.
    mutating func orbitAll(line: Int) throws(CodeError) -> Orbit {
        guard !rockets.isEmpty else {
            throw CodeError(line: line, "There's no rocket to put in orbit.",
                            hint: "Try create rocket and launch first.")
        }
        guard rockets.contains(where: \.isFlying) else {
            throw CodeError(line: line, "The rocket's still on the ground.",
                            hint: "Orbits start in the sky. Try launch first.")
        }
        guard stage.allowed.contains(.planet) else {
            throw CodeError(line: line, "There's nothing to circle in this corner of space.",
                            hint: "Planets live further out. Finish here and we'll find them.")
        }

        var createdPlanet = false
        if planets.isEmpty {
            try make(.planet, line: line)
            createdPlanet = true
        }
        guard let planet = planets.last else { throw CodeError(line: line, "Something odd happened.") }

        var moved: [Int] = []
        for rocket in rockets where rocket.isFlying {
            guard let index = bodies.firstIndex(where: { $0.id == rocket.id }) else { continue }
            bodies[index].flight = .orbiting(planet: planet.id)
            bodies[index].shiftX = 0
            bodies[index].shiftY = 0
            moved.append(rocket.id)
        }
        return Orbit(planet: planet, rockets: moved, createdPlanet: createdPlanet)
    }

    struct Expedition {
        var landed: [Int]
        var rovers: [Int]
        var bases: [Int]
    }

    /// Lands any rocket that's still flying, then sends every rover to explore the nearest base.
    mutating func exploreAll(line: Int) throws(CodeError) -> Expedition {
        guard stage == .moon else {
            throw CodeError(line: line, "There's nothing to explore up here yet.",
                            hint: "Explorers need somewhere to land. The Moon's coming up.")
        }
        guard has(.moon) else {
            throw CodeError(line: line, "There's no moon to explore!",
                            hint: "Try create moon before explore.")
        }
        guard has(.rover) else {
            throw CodeError(line: line, "Who's going to explore? There's no rover.",
                            hint: "Try create rover before explore.")
        }
        guard has(.base) else {
            throw CodeError(line: line, "The rover has nothing to find out there.",
                            hint: "Give it somewhere to go: create base.")
        }

        var landed: [Int] = []
        for rocket in rockets where rocket.isFlying {
            guard let index = bodies.firstIndex(where: { $0.id == rocket.id }) else { continue }
            bodies[index].flight = .landed
            bodies[index].shiftX = 0
            bodies[index].shiftY = 0
            landed.append(rocket.id)
        }
        var rovers: [Int] = [], bases: [Int] = []
        for index in bodies.indices where bodies[index].thing == .rover || bodies[index].thing == .base {
            bodies[index].explored = true
            if bodies[index].thing == .rover { rovers.append(bodies[index].id) } else { bases.append(bodies[index].id) }
        }
        return Expedition(landed: landed, rovers: rovers, bases: bases)
    }

    /// Bends space around every flying rocket, nudging it one step.
    mutating func move(_ direction: Direction, line: Int) throws(CodeError) -> [Int] {
        guard !rockets.isEmpty else {
            throw CodeError(line: line, "There's no rocket to move.", hint: "Try create rocket first.")
        }
        let flying = rockets.filter { $0.isFlying && $0.flight != .landed }
        guard !flying.isEmpty else {
            throw CodeError(line: line, "The rocket's not flying yet.", hint: "Every flight starts with launch.")
        }
        let span = 4
        var moved: [Int] = []
        for rocket in flying {
            if case .orbiting = rocket.flight { continue }
            guard let index = bodies.firstIndex(where: { $0.id == rocket.id }) else { continue }
            let x = rocket.shiftX + direction.delta.dx, y = rocket.shiftY + direction.delta.dy
            guard abs(x) <= span, abs(y) <= span else {
                throw CodeError(line: line, "Whoa, that's as far as space bends here!",
                                hint: "Try a different direction.")
            }
            bodies[index].shiftX = x
            bodies[index].shiftY = y
            bodies[index].facing = direction
            moved.append(rocket.id)
        }
        guard !moved.isEmpty else {
            throw CodeError(line: line, "A rocket in orbit follows its planet around.",
                            hint: "move is for rockets that are flying free.")
        }
        return moved
    }

    // MARK: - Describing

    /// Describes the universe in words, for VoiceOver.
    func spokenDescription() -> String {
        guard !bodies.isEmpty else { return "Empty space. Nothing has been created yet." }
        var parts: [String] = []
        for thing in Thing.allCases {
            let count = count(of: thing)
            guard count > 0 else { continue }
            var phrase = count == 1 ? thing.withArticle : "\(count) \(thing.plural)"
            if thing == .rocket {
                let states = rockets.map { rocket -> String in
                    switch rocket.flight {
                    case .grounded: "on the ground"
                    case .flying: "flying"
                    case .orbiting: "in orbit"
                    case .landed: "landed"
                    }
                }
                phrase += " (\(states.joined(separator: ", ")))"
            }
            parts.append(phrase)
        }
        return "Your universe has \(parts.joined(separator: ", "))."
    }

    /// The names planets get, in the order they're made.
    static let planetNames = ["Earth", "Mars", "Saturn", "Neptune"]
}

extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
