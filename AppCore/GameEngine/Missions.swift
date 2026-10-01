//
//  Missions.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import Foundation
import GameplayKit

// Each mission teaches one idea, and its world is built so that idea is the natural way to win:
// 1. Liftoff: sequencing. The order of the lines decides the flight.
// 2. Low Earth Orbit: loops. A loop comes back around, just like an orbit.
// 3. To The Moon: conditionals. The asteroids move every run, so the rocket has to check.

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

struct Mission: Identifiable, Hashable, Sendable {
    let id: MissionID
    let number: Int
    let title: String
    let concept: String
    let icon: String
    let summary: String
    let briefing: [String]
    let starterCode: String
    let blocks: [BlockKind]
    let hint: String

    static func == (lhs: Mission, rhs: Mission) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var next: Mission? {
        Mission.all.first { $0.number == number + 1 }
    }
}

// MARK: - The three missions

extension Mission {
    static let all: [Mission] = [.liftoff, .lowEarthOrbit, .toTheMoon]

    static let liftoff = Mission(
        id: .liftoff,
        number: 1,
        title: "Liftoff",
        concept: "Sequencing",
        icon: "flame.fill",
        summary: "Fly your rocket to the space station, one line at a time.",
        briefing: [
            "Hello, explorer. I'm the Guiding Light, and I'll be with you on every mission.",
            "Your rocket follows your code exactly, one line at a time, from top to bottom.",
            "Fly to the space station. Add moves to your code, then press Run and watch what happens."
        ],
        starterCode: """
        // Your code runs from top to bottom, one line at a time.
        // Fly to the space station!
        launch()
        move(up)

        """,
        blocks: [.launch, .move],
        hint: "Follow the dotted line and count the squares. How many moves up? How many to the right? Each move is one line of code."
    )

    static let lowEarthOrbit = Mission(
        id: .lowEarthOrbit,
        number: 2,
        title: "Low Earth Orbit",
        concept: "Loops",
        icon: "arrow.triangle.2.circlepath",
        summary: "Circle Earth 3 times, without writing the same code 3 times.",
        briefing: [
            "Welcome to orbit. Up here, going around and around is how you stay in space.",
            "The 4 moves in your code take the rocket around Earth once. But this mission needs 3 orbits.",
            "You could copy the lines 3 times... or you could tell the rocket to repeat them."
        ],
        starterCode: """
        // One trip around Earth takes 4 moves.
        // Can you make the rocket orbit 3 times?
        move(right)
        move(down)
        move(left)
        move(up)

        """,
        blocks: [.move, .repeatLoop],
        hint: "Put the 4 moves inside repeat 3 { }. Everything between the braces runs again each time around."
    )

    static let toTheMoon = Mission(
        id: .toTheMoon,
        number: 3,
        title: "To The Moon",
        concept: "Conditionals",
        icon: "moon.stars.fill",
        summary: "Cross an asteroid field that changes every time you fly.",
        briefing: [
            "The Moon is close now. But the asteroid field ahead changes every time you fly.",
            "You can't plan every move in advance. Instead, give your rocket a sensor: asteroidAhead.",
            "With if, your code can check before it moves, and decide for itself."
        ],
        starterCode: """
        // The asteroids move every time you run your code!
        // Use a sensor so the rocket can decide for itself.
        launch()
        repeat 7 {
            move(up)
        }

        """,
        blocks: [.launch, .move, .repeatLoop, .condition],
        hint: "Inside your repeat, before move(up), check: if asteroidAhead { move(right) }. The rocket will look every time around."
    )
}

// MARK: - Worlds

extension Mission {
    /// Builds this mission's world. Only To The Moon uses the seed: its asteroids move every run.
    func makeWorld(seed: UInt64) -> World {
        switch id {
        case .liftoff:
            World(width: 6, height: 6, rocket: GridPoint(x: 1, y: 5), isLaunched: false,
                  launchPad: GridPoint(x: 1, y: 5), station: GridPoint(x: 3, y: 2),
                  // The asteroid at (3, 4) means flying right first crashes: the order matters.
                  asteroids: [GridPoint(x: 3, y: 4), GridPoint(x: 0, y: 1), GridPoint(x: 5, y: 3)])
        case .lowEarthOrbit:
            World(width: 6, height: 6, rocket: GridPoint(x: 2, y: 2), isLaunched: true,
                  planetVertex: GridPoint(x: 3, y: 3),
                  asteroids: [GridPoint(x: 0, y: 5), GridPoint(x: 5, y: 0)])
        case .toTheMoon:
            Self.asteroidField(seed: seed)
        }
    }

    /// Makes an asteroid field that a rocket with a sensor can always cross. It "flies" the
    /// sensor strategy while placing asteroids, so every field is fair, while code that only
    /// memorizes one field will eventually crash.
    private static func asteroidField(seed: UInt64) -> World {
        let random = GKMersenneTwisterRandomSource(seed: seed)
        let width = 7, height = 8
        let pad = GridPoint(x: 1, y: height - 1)

        var asteroids: Set<GridPoint> = []
        var path: Set<GridPoint> = []
        for _ in 0..<20 where asteroids.count < 2 {
            asteroids = []
            path = [pad]
            var column = pad.x
            for row in stride(from: height - 2, through: 1, by: -1) {
                // The rocket is at (column, row + 1) and its sensor checks (column, row).
                if column + 1 < width && random.nextUniform() < 0.5 {
                    asteroids.insert(GridPoint(x: column, y: row))
                    column += 1
                    path.insert(GridPoint(x: column, y: row + 1))
                }
                path.insert(GridPoint(x: column, y: row))
            }
            path.insert(GridPoint(x: column, y: 0))
        }

        // Extra asteroids off the safe path make the field look wild without making it unfair.
        var decoys = 0
        for _ in 0..<40 where decoys < 5 {
            let point = GridPoint(x: random.nextInt(upperBound: width), y: 1 + random.nextInt(upperBound: height - 2))
            if !path.contains(point) && !asteroids.contains(point) {
                asteroids.insert(point)
                decoys += 1
            }
        }

        return World(width: width, height: height, rocket: pad, isLaunched: false,
                     launchPad: pad, moonRow: 0, asteroids: asteroids)
    }

    func hintPath(in world: World) -> [GridPoint] {
        switch id {
        case .liftoff:
            world.station.map { world.shortestPath(to: [$0]) } ?? []
        case .lowEarthOrbit:
            [GridPoint(x: 2, y: 2), GridPoint(x: 3, y: 2), GridPoint(x: 3, y: 3), GridPoint(x: 2, y: 3), GridPoint(x: 2, y: 2)]
        case .toTheMoon:
            world.shortestPath(to: (0..<world.width).map { GridPoint(x: $0, y: 0) })
        }
    }
}

// MARK: - Judging a flight

extension Mission {
    static let requiredOrbits = 3
    static let stressTestFields = 10

    func evaluate(_ trace: Trace, program: [Statement]) -> MissionResult {
        switch trace.halt {
        case .crashed(let line):
            return MissionResult(succeeded: false, title: "Asteroid impact!",
                                 message: "Line \(line) flew the rocket into an asteroid.",
                                 reflection: "Tap the rocket's trail to see which line made each move. Which one should change?",
                                 line: line)
        case .error(let error):
            return MissionResult(succeeded: false, title: "The rocket got confused",
                                 message: error.message, reflection: error.hint, line: error.line)
        case nil:
            break
        }

        let world = trace.finalWorld
        switch id {
        case .liftoff:
            guard let station = world.station else { break }
            if world.rocket == station {
                return MissionResult(succeeded: true, title: "Docked!",
                                     message: "You reached the space station in \(trace.moveCount) moves.",
                                     reflection: "Every line ran in order, top to bottom. Change the order and you change the flight. That's called sequencing, and you just did it.")
            }
            if !world.isLaunched {
                return MissionResult(succeeded: false, title: "Still on the pad",
                                     message: "The rocket never left the ground.",
                                     reflection: "Start your code with launch().")
            }
            return MissionResult(succeeded: false, title: "Not there yet",
                                 message: "You stopped short. The station is \(World.offsetPhrase(from: world.rocket, to: station)) from the rocket.",
                                 reflection: "Add a move for each square still between you and the station.")

        case .lowEarthOrbit:
            let orbits = Self.orbitCount(of: trace.path, around: world.planetVertex)
            guard orbits >= Self.requiredOrbits else {
                let message = orbits == 0
                    ? "The rocket didn't make it all the way around Earth."
                    : "That's \(orbits) \(orbits == 1 ? "orbit" : "orbits"). Earth needs \(Self.requiredOrbits)!"
                return MissionResult(succeeded: false, title: "\(orbits) of \(Self.requiredOrbits) orbits",
                                     message: message,
                                     reflection: program.usesRepeat ? "Check your repeat number." : "Try wrapping your moves in repeat 3 { }.")
            }
            let reflection = program.usesRepeat
                ? "Look at the rings. Each one is a single trip through your loop. A loop is code that comes back around, just like an orbit."
                : "You did it with \(program.commandCount) lines. Can you do it with fewer by using repeat?"
            return MissionResult(succeeded: true, title: "\(orbits) orbits complete!",
                                 message: "\(program.commandCount) lines of code flew \(trace.moveCount) moves.",
                                 reflection: reflection)

        case .toTheMoon:
            guard let moonRow = world.moonRow, world.rocket.y == moonRow else {
                let rows = world.rocket.y - (world.moonRow ?? 0)
                return MissionResult(succeeded: false, title: "Not there yet",
                                     message: "The Moon is still \(rows) \(rows == 1 ? "row" : "rows") above you.",
                                     reflection: "Keep moving up. Does your repeat run enough times?")
            }
            let crashes = Self.stressTest(program, mission: self)
            guard crashes == 0 else {
                return MissionResult(succeeded: false, title: "Lucky landing!",
                                     message: "You made it, but I tried your code on \(Self.stressTestFields) new asteroid fields and it failed on \(crashes).",
                                     reflection: "Code that only works once isn't finished yet. Use if asteroidAhead to check before each move up.")
            }
            return MissionResult(succeeded: true, title: "Touchdown!",
                                 message: "Your code landed on this field and \(Self.stressTestFields) new ones it had never seen.",
                                 reflection: "Your code didn't know where the asteroids would be. It checked, then decided. That's a conditional: code that can think on its feet.")
        }
        return MissionResult(succeeded: false, title: "Hmm", message: "Something unexpected happened.")
    }

    /// Runs the program on fresh asteroid fields, without animation, and counts the failures.
    private static func stressTest(_ program: [Statement], mission: Mission) -> Int {
        (0..<stressTestFields).reduce(0) { failures, _ in
            let world = mission.makeWorld(seed: UInt64.random(in: .min ... .max))
            let trace = Interpreter.run(program, in: world)
            let landed = trace.halt == nil && trace.finalWorld.rocket.y == world.moonRow
            return failures + (landed ? 0 : 1)
        }
    }

    /// Counts full trips around Earth by adding up how far the rocket turned around it
    /// (the winding number). Trips around the outside or back-and-forth moves don't count.
    static func orbitCount(of path: [GridPoint], around vertex: GridPoint?) -> Int {
        guard let vertex, path.count > 1 else { return 0 }
        let angles = path.map { atan2(Double($0.y) + 0.5 - Double(vertex.y), Double($0.x) + 0.5 - Double(vertex.x)) }
        var total = 0.0
        for (previous, next) in zip(angles, angles.dropFirst()) {
            var delta = next - previous
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            total += delta
        }
        return Int((abs(total) + 0.001) / (2 * .pi))
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
