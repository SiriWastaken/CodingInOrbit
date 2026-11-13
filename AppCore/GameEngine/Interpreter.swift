//
//  Interpreter.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import Foundation

// The Interpreter runs a program against a World and records every step as an event.
// Each event carries a snapshot of the universe as it looked right after that step.
// The whole run is worked out instantly; the GameSession then replays the events one at a
// time so the universe grows line by line. Because the run is recorded up front, Stop and
// speed controls just change how the replay happens.

struct StepEvent: Equatable, Sendable {
    let line: Int
    let kind: Kind
    /// The universe right after this step.
    let world: World

    enum Kind: Equatable, Sendable {
        case created(Body)
        /// `padsBuilt` are launchpads that launch() had to make on its own.
        case launched(rockets: [Int])
        case orbited(planet: Body, rockets: [Int], createdPlanet: Bool)
        case explored(landed: [Int], rovers: [Int], bases: [Int])
        case moved(rockets: [Int], direction: Direction)
        /// `preview` shows where the thing would appear, when the answer was "no".
        case sensed(Condition, result: Bool, preview: World?)
        case loopIterationStarted(iteration: Int, total: Int)
        case loopIterationEnded(iteration: Int, total: Int)
        case runtimeError(CodeError)
        case easterEgg(EasterEgg)

        /// How long this step takes compared to a single move.
        var pace: Double {
            switch self {
            case .created(let body): body.verb == .build ? 1.5 : 1.2
            case .launched: 1.8
            case .orbited: 2.2
            case .explored: 3.0
            case .moved: 1.0
            case .sensed: 1.1
            case .loopIterationStarted: 0.25
            case .loopIterationEnded: 0.3
            case .runtimeError: 1.0
            case .easterEgg: 1.2
            }
        }
    }

    /// A short description for VoiceOver users, read as each step happens.
    var spokenDescription: String {
        switch kind {
        case .created(let body):
            "Line \(line): \(body.verb.pastTense) \(body.thing.withArticle)."
        case .launched:
            "Line \(line): liftoff!"
        case .orbited(_, _, let createdPlanet):
            "Line \(line): the rocket is orbiting\(createdPlanet ? " a brand new planet" : "")."
        case .explored:
            "Line \(line): the rover explores and finds the base."
        case .moved(_, let direction):
            "Line \(line): space bends and the rocket moves \(direction.rawValue)."
        case .sensed(let condition, let result, _):
            "Line \(line): checking if \(condition.text). \(result ? "Yes." : "No.")"
        case .loopIterationStarted(let iteration, let total):
            "Repeat, round \(iteration) of \(total)."
        case .loopIterationEnded:
            "Round complete."
        case .runtimeError(let error):
            "Line \(line): \(error.message)"
        case .easterEgg:
            "Line \(line): a little surprise."
        }
    }
}

struct Trace: Sendable {
    enum Halt: Equatable, Sendable {
        case error(CodeError)
    }

    var events: [StepEvent] = []
    var finalWorld: World
    var halt: Halt?
    /// How many things the code made, counting the ones launch() and orbit() made on their own.
    var creationCount = 0
}

struct Interpreter {
    /// Stops runaway programs like repeat 1000000 { } before they freeze the app.
    static let stepLimit = 400

    private var world: World
    private var trace: Trace
    private var steps = 0

    private init(world: World) {
        self.world = world
        self.trace = Trace(finalWorld: world)
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

        do throws(CodeError) {
            switch statement {
            case .make(let verb, let thing, let line):
                let body = try world.make(thing, verb: verb, line: line)
                trace.creationCount += 1
                emit(line, .created(body))

            case .launch(let line):
                let liftoff = try world.launchAll(line: line)
                // Pads built on the way up appear first, so the pad is there before the rocket leaves it.
                for pad in liftoff.builtPads {
                    trace.creationCount += 1
                    emit(line, .created(pad), world: worldBeforeLiftoff(liftoff))
                }
                emit(line, .launched(rockets: liftoff.rockets))

            case .orbit(let line):
                let orbit = try world.orbitAll(line: line)
                if orbit.createdPlanet { trace.creationCount += 1 }
                emit(line, .orbited(planet: orbit.planet, rockets: orbit.rockets, createdPlanet: orbit.createdPlanet))

            case .explore(let line):
                let trip = try world.exploreAll(line: line)
                emit(line, .explored(landed: trip.landed, rovers: trip.rovers, bases: trip.bases))

            case .move(let direction, let line):
                let moved = try world.move(direction, line: line)
                emit(line, .moved(rockets: moved, direction: direction))

            case .repeatLoop(let count, let body, let line):
                guard count > 0 else { return }
                for iteration in 1...count {
                    guard countStep(line: line) else { return }
                    emit(line, .loopIterationStarted(iteration: iteration, total: count))
                    execute(body)
                    if isHalted { return }
                    emit(line, .loopIterationEnded(iteration: iteration, total: count))
                }

            case .ifElse(let condition, let then, let otherwise, let line):
                let result = world.sense(condition)
                // A "no" about something that doesn't exist yet shows where it could appear.
                let preview = (!result && !condition.negated) ? world.preview(condition.thing) : nil
                emit(line, .sensed(condition, result: result, preview: preview))
                execute(result ? then : (otherwise ?? []))

            case .easterEgg(let egg, let line):
                emit(line, .easterEgg(egg))
            }
        } catch {
            halt(error)
        }
    }

    /// The world as it was a moment before liftoff, with the pad in place but the rocket still on it.
    private func worldBeforeLiftoff(_ liftoff: World.Liftoff) -> World {
        var snapshot = world
        for id in liftoff.rockets { snapshot.setFlight(id: id, .grounded) }
        return snapshot
    }

    private mutating func countStep(line: Int) -> Bool {
        steps += 1
        guard steps <= Self.stepLimit else {
            halt(CodeError(line: line, "That's a lot of looping! I got dizzy after \(Self.stepLimit) steps and stopped.", hint: "Check your repeat numbers. The universe needs far fewer steps than that."))
            return false
        }
        return true
    }

    private mutating func emit(_ line: Int, _ kind: StepEvent.Kind, world override: World? = nil) {
        trace.events.append(StepEvent(line: line, kind: kind, world: override ?? world))
    }

    private mutating func halt(_ error: CodeError) {
        emit(error.line, .runtimeError(error))
        trace.halt = .error(error)
    }
}
