//
//  Missions.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import Foundation
import GameplayKit

// Each mission is a chapter in building a universe, and each one hides an idea that the
// code needs before it will work:
// 1. Liftoff: sequencing. A launchpad, then a rocket, then launch. Order changes the result.
// 2. Low Earth Orbit: loops. A ring of satellites is one line said five times.
// 3. To The Moon: conditionals. The Moon is sometimes already there, so the code has to look first.

enum MissionID: String, CaseIterable, Sendable {
    case liftoff, lowEarthOrbit, toTheMoon
}

struct MissionResult: Equatable, Sendable {
    var succeeded: Bool
    var title: String
    var message: String
    /// What the Guiding Light says afterwards: an insight after a win, a nudge after a miss.
    var reflection: String?
    /// The line to point at when something went wrong.
    var line: Int?
}

/// One thing the universe needs before the mission is done. Goals fill in as the world grows.
struct Goal: Identifiable, Sendable {
    let id: String
    let title: String
    let icon: String
    /// Bonus goals are extras for the curious. They never block the win.
    var isBonus = false
    /// What the Guiding Light says when this is the next thing missing.
    let nudge: String
    /// Said when the code finished but this still wasn't true.
    let missing: String
    /// A thing to draw as a ghost when hinting at this goal.
    var ghost: Thing?
    let isMet: @Sendable (World) -> Bool
}

struct Mission: Identifiable, Hashable, Sendable {
    let id: MissionID
    let number: Int
    let title: String
    let concept: String
    let icon: String
    let summary: String
    let stage: Stage
    let briefing: [String]
    let starterCode: String
    let blocks: [BlockKind]
    let goals: [Goal]

    static func == (lhs: Mission, rhs: Mission) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var next: Mission? {
        Mission.all.first { $0.number == number + 1 }
    }

    var coreGoals: [Goal] { goals.filter { !$0.isBonus } }
    var bonusGoals: [Goal] { goals.filter(\.isBonus) }
}

// MARK: - The three missions

extension Mission {
    static let all: [Mission] = [.liftoff, .lowEarthOrbit, .toTheMoon]

    static let requiredSatellites = 5
    static let stressTestUniverses = 10

    static let liftoff = Mission(
        id: .liftoff,
        number: 1,
        title: "Liftoff",
        concept: "Sequencing",
        icon: "flame.fill",
        summary: "Make a launchpad, then a rocket, then watch it go.",
        stage: .launchSite,
        briefing: [
            "Oh, hello! Welcome. It's awfully quiet out here. There's nothing at all, just you, me, and the dark.",
            "Here's the odd part: I think the words you type don't just move things. They make them. Try create(launchpad) and press Run. I honestly don't know what we'll get.",
            "If one line can make a launchpad, maybe another can make a rocket. And maybe something up here knows what launch() means. Shall we find out together?"
        ],
        starterCode: """
        // Nothing exists yet. Words make things.
        // What happens when you run this?
        create(launchpad)

        """,
        blocks: [.create, .launch],
        goals: [
            Goal(id: "pad", title: "Launchpad", icon: Thing.launchpad.icon,
                 nudge: "I'd start by giving the rocket somewhere to stand. See the ghost? Try create(launchpad).",
                 missing: "There's no launchpad yet. Rockets like having something to stand on.",
                 ghost: .launchpad, isMet: { $0.has(.launchpad) }),
            Goal(id: "rocket", title: "Rocket", icon: Thing.rocket.icon,
                 nudge: "A launchpad with nothing on it is lonely. What if we made a rocket too? Try create(rocket).",
                 missing: "The pad's ready, but there's no rocket to go with it.",
                 ghost: .rocket, isMet: { $0.has(.rocket) }),
            Goal(id: "liftoff", title: "Liftoff", icon: "flame.fill",
                 nudge: "The rocket's just sitting there, waiting. What do you think makes it go? I'd try launch().",
                 missing: "The rocket's still on the pad, waiting for its big moment.",
                 isMet: { $0.rockets.contains(where: \.isFlying) })
        ]
    )

    static let lowEarthOrbit = Mission(
        id: .lowEarthOrbit,
        number: 2,
        title: "Low Earth Orbit",
        concept: "Loops",
        icon: "arrow.triangle.2.circlepath",
        summary: "Fill empty space with a planet, a moon, and a ring of satellites.",
        stage: .orbit,
        briefing: [
            "Look how far we've come! Your rocket's up here now, but there's nothing for it to circle. I wonder what one line could do about that.",
            "A word made a launchpad. What if we ask for a planet? A moon? Something small and quick, like a satellite? I wonder if they need each other.",
            "Hmm, and if we want five satellites, typing the same line five times sounds tiring. Is there a way to say \"again\"?"
        ],
        starterCode: """
        // The rocket from Liftoff is waiting up here.
        // Every orbit needs something to circle...
        create(planet)

        """,
        blocks: [.create, .spawn, .summon, .orbit, .repeatLoop],
        goals: [
            Goal(id: "planet", title: "Planet", icon: Thing.planet.icon,
                 nudge: "Everything out here is so empty. A planet would give things something to circle. Try create(planet).",
                 missing: "There's no planet yet, so there's nothing to circle.",
                 ghost: .planet, isMet: { $0.has(.planet) }),
            Goal(id: "moon", title: "Moon", icon: Thing.moon.icon,
                 nudge: "Planets love company. Try create(moon) and let's see where it goes.",
                 missing: "Your planet is missing its moon.",
                 ghost: .moon, isMet: { $0.has(.moon) }),
            Goal(id: "satellites", title: "Satellites ×\(requiredSatellites)", icon: Thing.satellite.icon,
                 nudge: "A ring of \(requiredSatellites) satellites! You could write create(satellite) five times... or is there a way to say \"again\"?",
                 missing: "I count \(requiredSatellites) satellites needed, and not quite that many up there yet.",
                 ghost: .satellite, isMet: { $0.count(of: .satellite) >= requiredSatellites }),
            Goal(id: "orbit", title: "Orbit", icon: "arrow.triangle.2.circlepath",
                 nudge: "Your rocket's been so patient. What do you think orbit() does? Let's find out.",
                 missing: "The rocket's still drifting. It hasn't found anything to orbit yet.",
                 isMet: { world in world.rockets.contains { if case .orbiting = $0.flight { true } else { false } } }),
            Goal(id: "star", title: "A star", icon: Thing.star.icon, isBonus: true,
                 nudge: "Something's missing from the middle of all this. Maybe a star?",
                 missing: "", ghost: .star, isMet: { $0.has(.star) }),
            Goal(id: "planets", title: "Three planets", icon: "globe.europe.africa.fill", isBonus: true,
                 nudge: "Room for more planets? I'd love to see how many fit.",
                 missing: "", ghost: .planet, isMet: { $0.count(of: .planet) >= 3 })
        ]
    )

    static let toTheMoon = Mission(
        id: .toTheMoon,
        number: 3,
        title: "To The Moon",
        concept: "Conditionals",
        icon: "moon.stars.fill",
        summary: "Build a moon base that works in any universe.",
        stage: .moon,
        briefing: [
            "The Moon! Isn't she lovely tonight? Let's make her... hmm, wait. Sometimes she's already here when we arrive. The universe doesn't always start the same way.",
            "A rover and a base should be easy now. But I wonder what happens if we create a moon that's already there. Should we find out?",
            "What if the code could look around first, and decide for itself? There's something called if... and I think not might be in on it."
        ],
        starterCode: """
        // The Moon comes and goes. Some universes
        // start with her, and some don't.
        create(moon)

        """,
        blocks: [.create, .build, .spawn, .summon, .explore, .repeatLoop, .condition],
        goals: [
            Goal(id: "moon", title: "Moon", icon: Thing.moon.icon,
                 nudge: "Where's the Moon? Maybe create(moon) will bring her. Unless she's already here...",
                 missing: "There's still no moon down there.",
                 ghost: .moon, isMet: { $0.has(.moon) }),
            Goal(id: "rover", title: "Rover", icon: Thing.rover.icon,
                 nudge: "A moon without a rover is just a rock. Try spawn(rover).",
                 missing: "There's no rover to explore with.",
                 ghost: .rover, isMet: { $0.has(.rover) }),
            Goal(id: "base", title: "Base", icon: Thing.base.icon,
                 nudge: "The rover needs somewhere to go. How about build(base)?",
                 missing: "There's nothing for the rover to find. No base yet.",
                 ghost: .base, isMet: { $0.has(.base) }),
            Goal(id: "explore", title: "Explore", icon: "binoculars.fill",
                 nudge: "Everything's ready. What do you think explore() does? I'm curious too.",
                 missing: "Everything's built, but nobody's explored yet. Try explore().",
                 isMet: { world in world.bodies.contains { $0.thing == .rover && $0.explored } })
        ]
    )
}

// MARK: - Starting universes

extension Mission {
    /// Builds this mission's starting universe. Only To The Moon uses the seed: the Moon is
    /// sometimes already there. `gentle` makes the first run start empty, as the briefing says.
    func makeWorld(seed: UInt64, gentle: Bool = false) -> World {
        var world = World(stage: stage)
        let random = GKMersenneTwisterRandomSource(seed: seed)
        switch id {
        case .liftoff:
            break
        case .lowEarthOrbit:
            // The rocket from Liftoff, already up here.
            _ = try? world.make(.rocket, verb: .create, line: 0)
        case .toTheMoon:
            _ = try? world.make(.rocket, verb: .create, line: 0)
            if !gentle && random.nextBool() { _ = try? world.make(.moon, verb: .create, line: 0) }
            if !gentle && random.nextBool() { _ = try? world.make(.asteroid, verb: .create, line: 0) }
        }
        return world
    }

    /// What the Guiding Light says when a new universe arrives and something is different.
    func arrivalNote(for world: World) -> String? {
        guard id == .toTheMoon, world.has(.moon) else { return nil }
        return "Oh! The Moon's already here this time. Careful: what would happen if we made another?"
    }

    /// The next thing the Guiding Light would try: a nudge, and a ghost showing where it would appear.
    func nextStep(in world: World) -> (text: String, ghost: World?)? {
        guard let goal = coreGoals.first(where: { !$0.isMet(world) }) else { return nil }
        return (goal.nudge, goal.ghost.flatMap { world.preview($0) })
    }

    /// Bonus goals that are done, for the win card.
    func bonusesMet(in world: World) -> [Goal] {
        bonusGoals.filter { $0.isMet(world) }
    }
}

// MARK: - Judging a run

extension Mission {
    func evaluate(_ trace: Trace, program: [Statement]) -> MissionResult {
        if case .error(let error) = trace.halt {
            return MissionResult(succeeded: false, title: "Hmm, that didn't work",
                                 message: error.message, reflection: error.hint, line: error.line)
        }

        let world = trace.finalWorld
        if let missing = coreGoals.first(where: { !$0.isMet(world) }) {
            return MissionResult(succeeded: false, title: "Not quite yet", message: missing.missing,
                                 reflection: missing.nudge)
        }

        switch id {
        case .liftoff:
            return evaluateLiftoff(trace, program: program)
        case .lowEarthOrbit:
            return evaluateOrbit(trace, program: program)
        case .toTheMoon:
            return evaluateMoon(trace, program: program)
        }
    }

    private func evaluateLiftoff(_ trace: Trace, program: [Statement]) -> MissionResult {
        let creations = trace.events.compactMap { event -> Thing? in
            if case .created(let body) = event.kind { body.thing } else { nil }
        }
        let launchedPadByItself = trace.events.contains { event in
            if case .created(let body) = event.kind { body.autoBuilt } else { false }
        }
        let padFirst = creations.first == .launchpad && creations.contains(.rocket) && !launchedPadByItself
        let perfect = padFirst && program.commandCount == 3

        let reflection: String
        if launchedPadByItself {
            reflection = "Wait, I never saw you make a launchpad. launch() noticed the rocket had nothing to stand on and built one itself! Code can fill in gaps, but the order was still yours to choose."
        } else if creations.first == .rocket {
            reflection = "Did you see the pad slide in underneath the rocket? You made the rocket first, so the pad had to find it. Same lines, different order, different story. That's sequencing."
        } else {
            reflection = "Pad, rocket, launch. Every line ran in order, and each one changed what the next could do. Swap two lines and you'd grow a different universe. By the way, I think build(), spawn(), and summon() work too. Try them!"
        }
        return MissionResult(succeeded: true, title: "Liftoff!",
                             message: perfect
                                ? "Three lines took us from empty space to a rocket in flight. Everything up here exists because you said so."
                                : "From nothing to a rocket in flight. Everything up here exists because you said so.",
                             reflection: reflection)
    }

    private func evaluateOrbit(_ trace: Trace, program: [Statement]) -> MissionResult {
        let world = trace.finalWorld
        let satellites = world.count(of: .satellite)
        let bonuses = bonusesMet(in: world)
        let builtSolarSystem = bonuses.count == bonusGoals.count

        let message: String
        if builtSolarSystem {
            message = "A star, \(world.count(of: .planet)) planets, moons, and satellites. You didn't just orbit a planet, you built a whole solar system."
        } else {
            message = "A planet, a moon, \(satellites) satellites, and a rocket in orbit. All of it made by \(program.commandCount) lines."
        }

        let reflection: String
        if !program.usesRepeat {
            reflection = "That works! But I wonder... could one line say \"again\" for you? Try wrapping create(satellite) in repeat 5 { }."
        } else if builtSolarSystem {
            reflection = "See how the repeat did the typing for you? One line, said again and again. A loop is code that comes back around, just like an orbit."
        } else {
            reflection = "See how the repeat did the typing for you? A loop is code that comes back around, just like an orbit. I wonder what happens if you add create(star)..."
        }
        return MissionResult(succeeded: true, title: "In orbit!", message: message, reflection: reflection)
    }

    private func evaluateMoon(_ trace: Trace, program: [Statement]) -> MissionResult {
        let failures = Self.stressTest(program, mission: self)
        guard failures == 0 else {
            return MissionResult(succeeded: false, title: "Lucky landing!",
                                 message: "You built a moon base! But I tried your code in \(Self.stressTestUniverses) other universes, and it ran into trouble in \(failures) of them.",
                                 reflection: "Some universes already have a Moon, and create(moon) doesn't like making a second one. Could your code look first? Try if not moon { create(moon) }.")
        }
        return MissionResult(succeeded: true, title: "Touchdown!",
                             message: "A moon, a rover, a base, and an expedition. You've built a whole world to explore.",
                             reflection: "I tried your code in \(Self.stressTestUniverses) different universes, with and without a Moon, and it worked every time. It looked before it created. That's a conditional.")
    }

    /// Runs the program in fresh universes, without animation, and counts the ones where it fails.
    private static func stressTest(_ program: [Statement], mission: Mission) -> Int {
        (0..<stressTestUniverses).reduce(0) { failures, index in
            // Alternate on purpose so both kinds of universe are always tested.
            let withMoon = index % 2 == 0
            var world = mission.makeWorld(seed: UInt64.random(in: .min ... .max), gentle: true)
            if withMoon { _ = try? world.make(.moon, verb: .create, line: 0) }
            let trace = Interpreter.run(program, in: world)
            let worked = trace.halt == nil && mission.coreGoals.allSatisfy { $0.isMet(trace.finalWorld) }
            return failures + (worked ? 0 : 1)
        }
    }
}

// MARK: - Progress

enum MissionProgress {
    static let storageKey = "completedMissions"

    static func completedIDs(from stored: String) -> Set<String> {
        Set(stored.split(separator: ",").map(String.init))
    }

    static func markCompleted(_ id: MissionID) {
        let defaults = UserDefaults.standard
        var completed = completedIDs(from: defaults.string(forKey: storageKey) ?? "")
        completed.insert(id.rawValue)
        defaults.set(completed.sorted().joined(separator: ","), forKey: storageKey)
    }
}
