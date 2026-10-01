//
//  Interpreter.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import Foundation

// The Interpreter runs a program against a World and records every step as an event.
// The whole flight is worked out instantly; the GameSession then replays the events one at a
// time so the rocket moves line by line. Because the run is recorded up front, Stop and speed
// controls just change how the replay happens.

struct StepEvent: Equatable, Sendable {
    let line: Int
    let kind: Kind

    enum Kind: Equatable, Sendable {
        case launched(at: GridPoint)
        case moved(from: GridPoint, to: GridPoint, direction: Direction)
        case sensed(Condition, direction: Direction, target: GridPoint, result: Bool)
        case loopIterationStarted(iteration: Int, total: Int)
        case loopIterationEnded(iteration: Int, total: Int, path: [GridPoint])
        case crashed(at: GridPoint, from: GridPoint, direction: Direction)
        case runtimeError(CodeError)

        /// How long this step takes compared to a single move.
        var pace: Double {
            switch self {
            case .launched: 1.5
            case .moved: 1.0
            case .sensed: 0.9
            case .loopIterationStarted: 0.3
            case .loopIterationEnded: 0.5
            case .crashed: 1.6
            case .runtimeError: 1.0
            }
        }
    }

    /// A short description for VoiceOver users, read as each step happens.
    var spokenDescription: String {
        switch kind {
        case .launched: "Line \(line): liftoff!"
        case .moved(_, _, let direction): "Line \(line): moved \(direction.rawValue)."
        case .sensed(_, _, _, let result): "Line \(line): sensor check. \(result ? "Asteroid ahead!" : "All clear.")"
        case .loopIterationStarted(let iteration, let total): "Repeat, round \(iteration) of \(total)."
        case .loopIterationEnded: "Round complete."
        case .crashed: "Line \(line): crashed into an asteroid."
        case .runtimeError(let error): "Line \(line): \(error.message)"
        }
    }
}

struct Trace: Sendable {
    enum Halt: Equatable, Sendable {
        case crashed(line: Int)
        case error(CodeError)
    }

    var events: [StepEvent] = []
    /// Every square the rocket visited, in order, starting where it began.
    var path: [GridPoint]
    var finalWorld: World
    var halt: Halt?
    var moveCount = 0
}

struct Interpreter {
    /// Stops runaway programs like repeat 1000000 { } before they freeze the app.
    static let stepLimit = 400

    private var world: World
    private var trace: Trace
    private var steps = 0

    private init(world: World) {
        self.world = world
        self.trace = Trace(path: [world.rocket], finalWorld: world)
    }

    static func run(_ program: [Statement], in world: World) -> Trace {
        var interpreter = Interpreter(world: world)
        interpreter.execute(program)
        interpreter.trace.finalWorld = interpreter.world
        return interpreter.trace
    }

    private var isHalted: Bool { trace.halt != nil }

    private mutating func execute(_ statements: [Statement]) {
        for statement in statements {
            guard !isHalted else { return }
            execute(statement)
        }
    }

    private mutating func execute(_ statement: Statement) {
        guard countStep(line: statement.line) else { return }

        switch statement {
        case .launch(let line):
            guard !world.isLaunched else {
                halt(CodeError(line: line, "The rocket is already flying!", hint: "launch() only works on the launch pad. Try removing this line."))
                return
            }
            world.isLaunched = true
            world.heading = .up
            emit(line, .launched(at: world.rocket))

        case .move(let direction, let line):
            guard world.isLaunched else {
                halt(CodeError(line: line, "The rocket is still on the launch pad.", hint: "Add launch() before your first move."))
                return
            }
            let from = world.rocket
            let to = from.moved(direction)
            world.heading = direction
            guard world.contains(to) else {
                halt(CodeError(line: line, "Moving \(direction.rawValue) would fly out of the mission area.", hint: "Watch the edges. Try a different direction here."))
                return
            }
            if world.asteroids.contains(to) {
                emit(line, .crashed(at: to, from: from, direction: direction))
                trace.halt = .crashed(line: line)
                return
            }
            world.rocket = to
            trace.path.append(to)
            trace.moveCount += 1
            emit(line, .moved(from: from, to: to, direction: direction))

        case .repeatLoop(let count, let body, let line):
            guard count > 0 else { return }
            for iteration in 1...count {
                guard countStep(line: line) else { return }
                emit(line, .loopIterationStarted(iteration: iteration, total: count))
                let startIndex = trace.path.count - 1
                execute(body)
                if isHalted { return }
                emit(line, .loopIterationEnded(iteration: iteration, total: count, path: Array(trace.path[startIndex...])))
            }

        case .ifElse(let condition, let then, let otherwise, let line):
            let reading = world.sense(condition)
            emit(line, .sensed(condition, direction: world.heading, target: reading.target, result: reading.result))
            execute(reading.result ? then : (otherwise ?? []))
        }
    }

    private mutating func countStep(line: Int) -> Bool {
        steps += 1
        guard steps <= Self.stepLimit else {
            halt(CodeError(line: line, "Your code ran more than \(Self.stepLimit) steps, so I stopped it.", hint: "Check your repeat numbers. The rocket needs far fewer steps than that."))
            return false
        }
        return true
    }

    private mutating func emit(_ line: Int, _ kind: StepEvent.Kind) {
        trace.events.append(StepEvent(line: line, kind: kind))
    }

    private mutating func halt(_ error: CodeError) {
        emit(error.line, .runtimeError(error))
        trace.halt = .error(error)
    }
}
