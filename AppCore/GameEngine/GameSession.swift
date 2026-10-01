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
    private(set) var guideMood: GuideMood = .calm
    private(set) var stageDescription = ""
    /// How far through the current run the replay is, from 0 to 1.
    private(set) var runProgress: Double = 0
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
    @ObservationIgnored private var hasMadeMistake = false
    @ObservationIgnored private var hasCheeredAllBlocks = false
    @ObservationIgnored private var isSuitedUp = false

    /// Commands the rocket has carried out since the app opened, across every mission.
    private static var lifetimeCommands = 0

    var isRunning: Bool { phase == .running }
    var hasMoreBriefing: Bool { briefingIndex < mission.briefing.count - 1 }

    var result: MissionResult? {
        if case .finished(let result) = phase { result } else { nil }
    }

    /// True when the code parses and has something to run. The Run button glows when it is.
    var isCodeReady: Bool {
        guard phase == .editing, case .success(let program) = Parser.parse(code) else { return false }
        return !program.isEmpty
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
        sound.startAmbience(enabled: settings.sound)
    }

    func leave() {
        stop()
        narrator.stop()
        sound.stopAmbience()
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
        setGuide(mission.hint, mood: .curious)
    }

    private func setGuide(_ message: String, mood: GuideMood? = nil, speak: Bool = true) {
        guideMessage = message
        if let mood { guideMood = mood }
        if speak { narrator.speak(message, settings: settings) }
    }

    // MARK: - Editing

    func insert(_ snippet: String) {
        editor.insert(snippet)
        haptics.play(.pop, enabled: settings.haptics)
        sound.play(.pop, enabled: settings.sound)
        cheerIfAllBlocksUsed()
    }

    /// Called by the editor whenever the player changes the code.
    func codeDidChange() {
        errorLine = nil
        if selectedLine != nil { selectLine(nil) }
        if case .finished = phase { returnToEditing() }
        if guideMood == .concerned { guideMood = .calm }
    }

    func restoreStarterCode() {
        stop()
        code = mission.starterCode
        codeDidChange()
        setGuide(GuideVoice.freshStart, mood: .calm)
    }

    /// Links a line of code to its part of the trail. Choosing the same line again clears it.
    func selectLine(_ line: Int?) {
        selectedLine = (line == selectedLine) ? nil : line
        scene.highlightTrail(line: selectedLine)
        if line != nil { haptics.play(.select, enabled: settings.haptics) }
    }

    /// "Look at you go!" the first time the code uses every block this mission offers.
    private func cheerIfAllBlocksUsed() {
        guard !hasCheeredAllBlocks, mission.blocks.count > 1 else { return }
        let markers: [BlockKind: String] = [.launch: "launch(", .move: "move(", .repeatLoop: "repeat", .condition: "if "]
        let usedAll = mission.blocks.allSatisfy { kind in markers[kind].map { code.contains($0) } ?? true }
        guard usedAll else { return }
        hasCheeredAllBlocks = true
        setGuide(GuideVoice.allBlocksUsed, mood: .delighted)
    }

    // MARK: - Running

    func run() {
        guard !isRunning else { return }
        sound.play(.click, enabled: settings.sound)
        switch Parser.parse(code) {
        case .failure(let error):
            report(error)
        case .success(let program):
            guard !program.isEmpty else {
                setGuide(GuideVoice.emptyCode, mood: .curious)
                haptics.play(.error, enabled: settings.haptics)
                return
            }
            if !fieldIsFresh || phase != .editing { resetStage(newField: true) }
            fieldIsFresh = false
            errorLine = nil
            selectedLine = nil
            gutterNotes = [:]
            runProgress = 0

            let trace = Interpreter.run(program, in: world)
            phase = .running
            setGuide(GuideVoice.pick(GuideVoice.running), mood: .curious, speak: false)
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
        runProgress = 0
        guideMood = .calm
        resetStage(newField: false)
    }

    /// Goes back to editing after a finished run. To The Moon gets a fresh asteroid field.
    private func returnToEditing() {
        phase = .editing
        activeLine = nil
        gutterNotes = [:]
        runProgress = 0
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

        for (index, event) in trace.events.enumerated() {
            let duration = stepDuration * event.kind.pace
            activeLine = event.line
            updateNotes(for: event)
            scene.play(event, duration: duration)
            giveFeedback(for: event, rocketAt: rocket)

            switch event.kind {
            case .moved(_, let to, _):
                rocket = to
                countCommand()
            case .launched:
                launched = true
                countCommand()
            case .easterEgg(let egg):
                reactToEasterEgg(egg)
            default:
                break
            }
            stageDescription = world.spokenDescription(rocketAt: rocket, launched: launched)

            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                return
            }
            runProgress = Double(index + 1) / Double(trace.events.count)
        }

        activeLine = nil
        // Code that's only secret commands is just for fun: no win or loss.
        if program.allSatisfy(\.isEasterEgg) {
            phase = .editing
            runProgress = 0
            fieldIsFresh = true
            return
        }
        finish(with: mission.evaluate(trace, program: program))
    }

    private func countCommand() {
        Self.lifetimeCommands += 1
        if Self.lifetimeCommands == 10 {
            setGuide(GuideVoice.tenthCommand, mood: .delighted, speak: false)
        }
    }

    private func reactToEasterEgg(_ egg: EasterEgg) {
        sound.play(.sparkle, enabled: settings.sound)
        switch egg {
        case .hello:
            setGuide(GuideVoice.pick(GuideVoice.hello), mood: .delighted)
        case .suitUp:
            setGuide(isSuitedUp ? GuideVoice.suitUpAgain : GuideVoice.suitUp, mood: .delighted)
            isSuitedUp = true
        case .stargaze:
            setGuide(GuideVoice.stargaze, mood: .delighted)
        }
    }

    private func finish(with result: MissionResult) {
        phase = .finished(result)
        runTask = nil
        runProgress = 1
        if result.succeeded {
            scene.celebrate()
            haptics.play(.success, enabled: settings.haptics)
            sound.play(.success, enabled: settings.sound)
            MissionProgress.markCompleted(mission.id)
        } else {
            errorLine = result.line
            hasMadeMistake = true
            haptics.play(.error, enabled: settings.haptics)
            sound.play(.error, enabled: settings.sound)
        }
        setGuide(result.reflection ?? result.message, mood: result.succeeded ? .delighted : .concerned)
    }

    private func report(_ error: CodeError) {
        errorLine = error.line
        // The very first slip of the session gets a little reassurance first.
        let opener = hasMadeMistake ? "" : GuideVoice.firstMistake + " "
        hasMadeMistake = true
        setGuide("\(opener)Line \(error.line): \(error.explanation)", mood: .concerned)
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
        case .easterEgg:
            haptics.play(.success, enabled: settings.haptics)
        case .loopIterationStarted:
            break
        }
        narrator.announce(event.spokenDescription)
    }
}
