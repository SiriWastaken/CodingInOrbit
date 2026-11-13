//
//  Missions.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import Foundation

// Three acts, each about one idea, and then the whole sky:
// 1. Liftoff: sequencing. launch, then climb. Each line runs after the one before it.
// 2. Orbit: loops. Say a move once, repeat it four times, and swing around Earth.
// 3. Moon: conditionals. An asteroid is sometimes in the way, so the code looks first.
// Free Play has no goals at all: everything you've learned, and an empty sky.

enum MissionID: String, CaseIterable, Sendable {
    case liftoff, orbit, moon, freePlay
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
}

// MARK: - The lessons

extension Mission {
    static let all: [Mission] = [.liftoff, .orbit, .moon]

    static let liftoff = Mission(
        id: .liftoff,
        number: 1,
        title: "Liftoff",
        concept: "Sequencing",
        icon: "flame.fill",
        summary: "Launch from Earth",
        stage: .launchSite,
        briefing: ["Ready to fly? Type launch to begin."],
        starterCode: "",
        blocks: [.launch, .move],
        goals: [
            Goal(id: "liftoff", title: "Liftoff", icon: "flame.fill",
                 nudge: "Ready to fly? Type launch to begin.",
                 missing: "The rocket's still on the pad.",
                 isMet: { $0.rockets.contains(where: \.isFlying) }),
            Goal(id: "space", title: "Reach space", icon: "arrow.up",
                 nudge: "Nice! Now move up to leave the atmosphere.",
                 missing: "Still in the atmosphere.",
                 isMet: { $0.rockets.contains { $0.shiftY >= 2 } })
        ]
    )

    static let orbit = Mission(
        id: .orbit,
        number: 2,
        title: "Orbit",
        concept: "Loops",
        icon: "globe.americas.fill",
        summary: "Circle the planet",
        stage: .orbit,
        briefing: ["To orbit, you need to repeat the same move. Try: repeat 4 times: move right"],
        starterCode: "",
        blocks: [.move, .repeatLoop],
        goals: [
            Goal(id: "across", title: "Across", icon: "arrow.left.and.right",
                 nudge: "Try: repeat 4 times: move right",
                 missing: "The rocket hasn't gone sideways yet.",
                 isMet: { $0.rockets.contains { $0.shiftX != 0 } }),
            Goal(id: "around", title: "Around", icon: "arrow.up.and.down",
                 nudge: "Now another loop: repeat 4 times: move up",
                 missing: "Halfway around!",
                 isMet: { $0.rockets.contains { $0.shiftY != 0 } })
        ]
    )

    static let moon = Mission(
        id: .moon,
        number: 3,
        title: "Moon",
        concept: "Conditionals",
        icon: "moon.stars.fill",
        summary: "Reach the moon",
        stage: .moon,
        briefing: ["The moon is far away. You'll need to navigate around obstacles. Try: if asteroid: move left"],
        starterCode: "",
        blocks: [.move, .repeatLoop, .condition, .land],
        goals: [
            Goal(id: "close", title: "Get close", icon: "arrow.down",
                 nudge: "See? The rocket reacts to its environment. Now get closer: repeat 2 times: move down",
                 missing: "The moon's still a long way down.",
                 isMet: { $0.rockets.contains { $0.shiftY <= World.landingDistance || $0.flight == .landed } }),
            Goal(id: "land", title: "Touchdown", icon: "flag.fill",
                 nudge: "You're right above it. Type land.",
                 missing: "Almost there!",
                 isMet: { $0.rockets.contains { $0.flight == .landed } })
        ]
    )

    /// No goals, no lessons. Everything you've learned and an empty sky.
    static let freePlay = Mission(
        id: .freePlay,
        number: 4,
        title: "Free Play",
        concept: "Anything",
        icon: "sparkles",
        summary: "Build anything",
        stage: .orbit,
        briefing: ["Build anything. The universe is yours."],
        starterCode: "",
        blocks: [.create, .move, .orbit, .repeatLoop, .condition],
        goals: []
    )
}

// MARK: - Starting universes

extension Mission {
    /// `surprise` lets the Moon's asteroid come and go between runs. The first run always has
    /// one, so the briefing's `if asteroid` has something to find.
    func makeWorld(surprise: Bool = false) -> World {
        var world = World(stage: stage)
        switch id {
        case .liftoff:
            // The rocket is already waiting on its pad.
            _ = try? world.make(.launchpad, line: 0)
            _ = try? world.make(.rocket, line: 0)
        case .orbit:
            // Earth below, and the rocket from Liftoff already up here.
            _ = try? world.make(.planet, line: 0)
            _ = try? world.make(.rocket, line: 0)
        case .moon:
            _ = try? world.make(.moon, line: 0)
            _ = try? world.make(.rocket, line: 0)
            if !surprise || Bool.random() { _ = try? world.make(.asteroid, line: 0) }
        case .freePlay:
            _ = try? world.make(.rocket, line: 0)
        }
        return world
    }

    /// The next thing the Guiding Light would try: a nudge, and a ghost showing where it would appear.
    func nextStep(in world: World) -> (text: String, ghost: World?)? {
        guard let goal = goals.first(where: { !$0.isMet(world) }) else { return nil }
        return (goal.nudge, goal.ghost.flatMap { world.preview($0) })
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
        let missing = goals.first { !$0.isMet(world) }
        let climb = world.rockets.map(\.shiftY).max() ?? 0

        switch id {
        case .liftoff:
            guard let missing else { return win("You did it! You're in space.") }
            // Each run gets the next step, so it feels like a conversation.
            if missing.id == "space" && climb == 1 { return miss("Keep going. You're almost there.") }
            return miss(missing.nudge)
        case .orbit:
            guard program.usesRepeat else { return miss("To orbit, you need to repeat the same move. Try: repeat 4 times: move right") }
            guard missing == nil else { return miss("See how that works? You just created a loop. Now another: repeat 4 times: move up") }
            return win("You're orbiting! The Earth is below you.")
        case .moon:
            guard program.usesIf else { return miss("Asteroids drift through here. Make the rocket look first: if asteroid: move left") }
            if let missing { return miss(missing.nudge) }
            return win("You made it. Touchdown.")
        case .freePlay:
            return win("")
        }
    }

    private func win(_ line: String) -> MissionResult {
        MissionResult(succeeded: true, title: title, message: line, reflection: line)
    }

    private func miss(_ line: String) -> MissionResult {
        MissionResult(succeeded: false, title: title, message: line, reflection: line)
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
