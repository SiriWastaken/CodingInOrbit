//
//  Syntax.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import Foundation

// The rocket's language is a tiny slice of Swift. Programs are turned into a tree of
// statements (an AST) so that repeat and if can hold other statements inside them.
//
//     launch()
//     repeat 3 {
//         if asteroidAhead {
//             move(right)
//         }
//         move(up)
//     }

enum Direction: String, CaseIterable, Sendable {
    case up, down, left, right

    /// How one move in this direction changes a grid position (y grows downward).
    var delta: (dx: Int, dy: Int) {
        switch self {
        case .up: (0, -1)
        case .down: (0, 1)
        case .left: (-1, 0)
        case .right: (1, 0)
        }
    }

    /// The rocket's rotation when facing this direction (radians, counterclockwise from up).
    var angle: CGFloat {
        switch self {
        case .up: 0
        case .left: .pi / 2
        case .down: .pi
        case .right: -.pi / 2
        }
    }
}

/// A sensor the rocket can check with `if`.
enum Condition: String, CaseIterable, Sendable {
    case asteroidAhead
}

indirect enum Statement: Equatable, Sendable {
    case launch(line: Int)
    case move(Direction, line: Int)
    case repeatLoop(count: Int, body: [Statement], line: Int)
    case ifElse(Condition, then: [Statement], otherwise: [Statement]?, line: Int)

    var line: Int {
        switch self {
        case .launch(let line), .move(_, let line), .repeatLoop(_, _, let line), .ifElse(_, _, _, let line):
            line
        }
    }

    /// How many commands this statement contains, counting itself.
    var commandCount: Int {
        switch self {
        case .launch, .move:
            1
        case .repeatLoop(_, let body, _):
            1 + body.commandCount
        case .ifElse(_, let then, let otherwise, _):
            1 + then.commandCount + (otherwise?.commandCount ?? 0)
        }
    }

    var usesRepeat: Bool {
        switch self {
        case .launch, .move: false
        case .repeatLoop: true
        case .ifElse(_, let then, let otherwise, _): then.usesRepeat || (otherwise?.usesRepeat ?? false)
        }
    }

    var usesIf: Bool {
        switch self {
        case .launch, .move: false
        case .repeatLoop(_, let body, _): body.usesIf
        case .ifElse: true
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
