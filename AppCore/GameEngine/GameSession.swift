//
//  GameSession.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI
import Observation

// GameSession runs one mission. It's the bridge between everything:
//
//   code text ──Parser──▶ program ──Interpreter──▶ trace of steps
//                                                     │
//        replayed one step at a time, at the chosen speed
//                                                     ▼
//        OrbitScene animates · editor highlights the line · haptics, sound, voice
//
// Stopping cancels the replay task, so the rocket stops right away.

enum RunSpeed: String, CaseIterable, Identifiable {
    case slow, normal, fast

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .slow: "tortoise.fill"
        case .normal: "figure.walk"
        case .fast: "hare.fill"
        }
    }

    /// Seconds for one move.
    var stepDuration: Double {
        switch self {
        case .slow: 1.0
        case .normal: 0.6
        case .fast: 0.3
        }
    }
}

/// A small label in the editor's margin, like "2/3" next to a repeat or "yes" next to an if.
struct GutterNote: Equatable {
    enum Style { case loop, yes, no }
    let text: String
    let style: Style
}

@MainActor
@Observable
final class GameSession {
    enum Phase: Equatable {
        case editing
        case running
        case finished(MissionResult)
    }

    let mission: Mission
    var code: String
    var speed: RunSpeed = .normal
    var settings = FeedbackSettings() {
        didSet { scene.style = settings.style }
    }

    private(set) var phase: Phase = .editing
    private(set) var activeLine: Int?
    private(set) var errorLine: Int?
    private(set) var selectedLine: Int?
    private(set) var gutterNotes: [Int: GutterNote] = [:]
    private(set) var guideMessage: String
    private(set) var stageDescription = ""
    private var briefingIndex = 0

    @ObservationIgnored let scene: OrbitScene
    @ObservationIgnored let editor = EditorBridge()
    @ObservationIgnored private var world: World
    /// False once a run has used this asteroid field, so the next run gets a new one.
    @ObservationIgnored private var fieldIsFresh = true
    @ObservationIgnored private var runTask: Task<Void, Never>?
    @ObservationIgnored private let haptics = HapticsPlayer()
    @ObservationIgnored private let sound = SoundPlayer()
    @ObservationIgnored private let narrator = Narrator()

    var isRunning: Bool { phase == .running }
    var hasMoreBriefing: Bool { briefingIndex < mission.briefing.count - 1 }

    var result: MissionResult? {
        if case .finished(let result) = phase { result } else { nil }
    }

    init(mission: Mission) {
        self.mission = mission
        self.code = mission.starterCode
        self.world = mission.makeWorld(seed: UInt64.random(in: .min ... .max))
        self.guideMessage = mission.briefing.first ?? ""
        self.scene = OrbitScene(size: CGSize(width: 600, height: 600))
        scene.onTrailTapped = { [weak self] line in self?.selectLine(line) }
    }

    // MARK: - Lifecycle

    func start() {
        scene.style = settings.style
        resetStage(newField: false)
        narrator.speak(guideMessage, settings: settings)
    }

    func leave() {
        stop()
        narrator.stop()
    }

    // MARK: - The Guiding Light

    func advanceBriefing() {
        guard hasMoreBriefing else { return }
        briefingIndex += 1
        setGuide(mission.briefing[briefingIndex])
    }

    func repeatGuide() {
        narrator.speak(guideMessage, settings: settings, force: true)
    }

    func showHint() {
        if phase != .editing { returnToEditing() }
        scene.showHint(mission.hintPath(in: world))
        setGuide(mission.hint)
    }

    private func setGuide(_ message: String, speak: Bool = true) {
        guideMessage = message
        if speak { narrator.speak(message, settings: settings) }
    }

    // MARK: - Editing

    func insert(_ snippet: String) {
        editor.insert(snippet)
    }

    /// Called by the editor whenever the player changes the code.
    func codeDidChange() {
        errorLine = nil
        if selectedLine != nil { selectLine(nil) }
        if case .finished = phase { returnToEditing() }
    }

    func restoreStarterCode() {
        stop()
        code = mission.starterCode
        codeDidChange()
    }

    /// Links a line of code to its part of the trail. Choosing the same line again clears it.
    func selectLine(_ line: Int?) {
        selectedLine = (line == selectedLine) ? nil : line
        scene.highlightTrail(line: selectedLine)
    }

    // MARK: - Running

    func run() {
        guard !isRunning else { return }
        switch Parser.parse(code) {
        case .failure(let error):
            report(error)
        case .success(let program):
            guard !program.isEmpty else {
                setGuide("Your code is empty! Tap a block below, or type a command like launch().")
                haptics.play(.error, enabled: settings.haptics)
                return
            }
            if !fieldIsFresh || phase != .editing { resetStage(newField: true) }
            fieldIsFresh = false
            errorLine = nil
            selectedLine = nil
            gutterNotes = [:]

            let trace = Interpreter.run(program, in: world)
            phase = .running
            setGuide("Watch closely. The highlighted line is the one the rocket is running.", speak: false)
            runTask = Task { [weak self] in
                await self?.play(trace, program: program)
            }
        }
    }

    func stop() {
        runTask?.cancel()
        runTask = nil
        guard phase != .editing else { return }
        phase = .editing
        activeLine = nil
        gutterNotes = [:]
        resetStage(newField: false)
    }

    /// Goes back to editing after a finished run. To The Moon gets a fresh asteroid field.
    private func returnToEditing() {
        phase = .editing
        activeLine = nil
        gutterNotes = [:]
        resetStage(newField: true)
    }

    private func resetStage(newField: Bool) {
        if newField {
            world = mission.makeWorld(seed: UInt64.random(in: .min ... .max))
        }
        fieldIsFresh = true
        scene.load(world)
        stageDescription = world.spokenDescription(rocketAt: world.rocket, launched: world.isLaunched)
    }

    private var stepDuration: Double {
        // VoiceOver needs time to read each step aloud.
        UIAccessibility.isVoiceOverRunning ? max(speed.stepDuration, RunSpeed.slow.stepDuration) : speed.stepDuration
    }

    private func play(_ trace: Trace, program: [Statement]) async {
        var rocket = world.rocket
        var launched = world.isLaunched

        for event in trace.events {
            let duration = stepDuration * event.kind.pace
            activeLine = event.line
            updateNotes(for: event)
            scene.play(event, duration: duration)
            giveFeedback(for: event, rocketAt: rocket)

            switch event.kind {
            case .moved(_, let to, _): rocket = to
            case .launched: launched = true
            default: break
            }
            stageDescription = world.spokenDescription(rocketAt: rocket, launched: launched)

            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                return
            }
        }

        activeLine = nil
        finish(with: mission.evaluate(trace, program: program))
    }

    private func finish(with result: MissionResult) {
        phase = .finished(result)
        runTask = nil
        if result.succeeded {
            scene.celebrate()
            haptics.play(.success, enabled: settings.haptics)
            sound.play(.success, enabled: settings.sound)
            MissionProgress.markCompleted(mission.id)
        } else {
            errorLine = result.line
            haptics.play(.error, enabled: settings.haptics)
            sound.play(.error, enabled: settings.sound)
        }
        setGuide(result.reflection ?? result.message)
    }

    private func report(_ error: CodeError) {
        errorLine = error.line
        setGuide("Line \(error.line): \(error.explanation)")
        haptics.play(.error, enabled: settings.haptics)
        sound.play(.error, enabled: settings.sound)
        scene.play(StepEvent(line: error.line, kind: .runtimeError(error)), duration: 0.5)
    }

    private func updateNotes(for event: StepEvent) {
        switch event.kind {
        case .loopIterationStarted(let iteration, let total):
            gutterNotes[event.line] = GutterNote(text: "\(iteration)/\(total)", style: .loop)
        case .sensed(_, _, _, let result):
            gutterNotes[event.line] = GutterNote(text: result ? "yes" : "no", style: result ? .yes : .no)
        default:
            break
        }
    }

    private func giveFeedback(for event: StepEvent, rocketAt rocket: GridPoint) {
        let pan = { (cell: GridPoint) -> Float in
            Float(cell.x) / Float(max(self.world.width - 1, 1)) * 1.6 - 0.8
        }
        switch event.kind {
        case .launched:
            haptics.play(.launch, enabled: settings.haptics)
            sound.play(.launch, pan: pan(rocket), enabled: settings.sound)
        case .moved(_, let to, let direction):
            haptics.play(.move, enabled: settings.haptics)
            let cue: SoundCue = switch direction {
            case .up: .moveUp
            case .down: .moveDown
            case .left, .right: .moveSide
            }
            sound.play(cue, pan: pan(to), enabled: settings.sound)
        case .sensed:
            haptics.play(.sense, enabled: settings.haptics)
            sound.play(.ping, pan: pan(rocket), enabled: settings.sound)
        case .loopIterationEnded(_, _, let path):
            haptics.play(.loop, enabled: settings.haptics)
            if path.count >= 4 && path.first == path.last {
                sound.play(.ring, pan: pan(rocket), enabled: settings.sound)
            }
        case .crashed(let at, _, _):
            haptics.play(.crash, enabled: settings.haptics)
            sound.play(.crash, pan: pan(at), enabled: settings.sound)
        case .runtimeError:
            haptics.play(.error, enabled: settings.haptics)
            sound.play(.error, pan: pan(rocket), enabled: settings.sound)
        case .loopIterationStarted:
            break
        }
        narrator.announce(event.spokenDescription)
    }
}
