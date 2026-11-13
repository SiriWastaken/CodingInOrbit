//
//  Syntax.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import Foundation

// RocketScript: the language of Coding In Orbit. It reads like English, so a ten-year-old
// can guess what it does. Programs become a tree of statements (an AST) so that repeat and
// if can hold other statements inside them. Indented lines belong to the line above them.
//
//     create launchpad
//     create a rocket
//     launch
//     repeat 3 times:
//         create satellite
//     if not moon:
//         create moon
//
// Parentheses are optional, so Swift-style create(rocket) and launch() work too.

/// Everything that can exist in the universe.
enum Thing: String, CaseIterable, Sendable, Codable {
    case launchpad, rocket, star, planet, moon, satellite, asteroid, comet, rover, base

    /// "a launchpad", "an asteroid"
    var article: String {
        "aeiou".contains(rawValue.first ?? "x") ? "an" : "a"
    }

    var withArticle: String { "\(article) \(rawValue)" }

    var plural: String {
        switch self {
        case .base: "bases"
        default: rawValue + "s"
        }
    }

    var icon: String {
        switch self {
        case .launchpad: "square.stack.3d.up.fill"
        case .rocket: "airplane.departure"
        case .star: "sun.max.fill"
        case .planet: "globe.europe.africa.fill"
        case .moon: "moon.fill"
        case .satellite: "antenna.radiowaves.left.and.right"
        case .asteroid: "circle.hexagongrid.fill"
        case .comet: "sparkle"
        case .rover: "car.side.fill"
        case .base: "house.fill"
        }
    }
}

enum Direction: String, CaseIterable, Sendable {
    case up, down, left, right

    /// How one move in this direction shifts the rocket (y grows upward on screen).
    var delta: (dx: Int, dy: Int) {
        switch self {
        case .up: (0, 1)
        case .down: (0, -1)
        case .left: (-1, 0)
        case .right: (1, 0)
        }
    }
}

/// Secret commands. They don't change the universe, they just make something nice happen.
enum EasterEgg: String, Sendable {
    case hello, suitUp, stargaze, help
}

/// A question the universe can answer: does this thing exist yet? `if not moon` asks the opposite.
struct Condition: Equatable, Sendable {
    var thing: Thing
    var negated = false

    var text: String { "\(negated ? "not " : "")\(thing.rawValue)" }
}

indirect enum Statement: Equatable, Sendable {
    case make(Thing, line: Int)
    case launch(line: Int)
    case orbit(line: Int)
    case explore(line: Int)
    case land(line: Int)
    case move(Direction, line: Int)
    case repeatLoop(count: Int, body: [Statement], line: Int)
    case ifElse(Condition, then: [Statement], otherwise: [Statement]?, line: Int)
    case easterEgg(EasterEgg, line: Int)

    var line: Int {
        switch self {
        case .make(_, let line), .launch(let line), .orbit(let line), .explore(let line), .land(let line), .move(_, let line),
             .repeatLoop(_, _, let line), .ifElse(_, _, _, let line), .easterEgg(_, let line):
            line
        }
    }

    var isEasterEgg: Bool {
        if case .easterEgg = self { true } else { false }
    }

    /// How many commands this statement contains, counting itself. Easter eggs don't count.
    var commandCount: Int {
        switch self {
        case .easterEgg:
            0
        case .make, .launch, .orbit, .explore, .land, .move:
            1
        case .repeatLoop(_, let body, _):
            1 + body.commandCount
        case .ifElse(_, let then, let otherwise, _):
            1 + then.commandCount + (otherwise?.commandCount ?? 0)
        }
    }

    var usesRepeat: Bool {
        switch self {
        case .repeatLoop: true
        case .ifElse(_, let then, let otherwise, _): then.usesRepeat || (otherwise?.usesRepeat ?? false)
        default: false
        }
    }

    var usesIf: Bool {
        switch self {
        case .repeatLoop(_, let body, _): body.usesIf
        case .ifElse: true
        default: false
        }
    }
}

extension Array where Element == Statement {
    var commandCount: Int { reduce(0) { $0 + $1.commandCount } }
    var usesRepeat: Bool { contains { $0.usesRepeat } }
    var usesIf: Bool { contains { $0.usesIf } }
}

/// A friendly explanation of what went wrong, and where.
struct CodeError: Error, Equatable, Sendable {
    let line: Int
    let message: String
    let hint: String?

    init(line: Int, _ message: String, hint: String? = nil) {
        self.line = line
        self.message = message
        self.hint = hint
    }

    /// The message and hint together, ready for the Guiding Light to say.
    var explanation: String {
        [message, hint].compactMap { $0 }.joined(separator: " ")
    }
}

enum Suggestions {
    /// Finds the known word closest to a typo, like "lanch" → "launch".
    static func closest(to word: String, in candidates: [String]) -> String? {
        let lowered = word.lowercased()
        let scored = candidates.map { ($0, editDistance(lowered, $0.lowercased())) }
        guard let best = scored.min(by: { $0.1 < $1.1 }) else { return nil }
        let allowed = Swift.max(1, Swift.min(2, word.count / 3))
        return best.1 <= allowed ? best.0 : nil
    }

    /// Levenshtein distance: the fewest single-letter edits that turn one word into another.
    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = Swift.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[b.count]
    }
}
