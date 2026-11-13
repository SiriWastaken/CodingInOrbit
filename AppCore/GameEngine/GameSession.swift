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
//        CosmosScene grows the universe · editor highlights the line · haptics, sound, voice
//
// Stopping cancels the replay task, so the universe stops growing right away.

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
    /// Goals that are true of the universe as it looks right now, filling in as the replay builds it.
    private(set) var metGoals: Set<String> = []
    private var briefingIndex = 0

    @ObservationIgnored let scene: CosmosScene
    @ObservationIgnored let editor = EditorBridge()
    @ObservationIgnored private var world: World
    /// What the last run built, so hints can look at what's already there.
    @ObservationIgnored private var lastWorld: World?
    /// False once a run has used this starting universe, so the next run gets a new one.
    @ObservationIgnored private var fieldIsFresh = true
    @ObservationIgnored private var runTask: Task<Void, Never>?
    @ObservationIgnored private let haptics = HapticsPlayer()
    @ObservationIgnored private let sound = SoundPlayer()
    @ObservationIgnored private let narrator = Narrator()
    @ObservationIgnored private var hasMadeMistake = false
    @ObservationIgnored private var hasCheeredAllBlocks = false
    @ObservationIgnored private var isSuitedUp = false
    @ObservationIgnored private var seenThings: Set<Thing> = []

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
        // The first universe starts the way the briefing says it will.
        self.world = mission.makeWorld(seed: UInt64.random(in: .min ... .max), gentle: true)
        self.guideMessage = mission.briefing.first ?? ""
        self.scene = CosmosScene(size: CGSize(width: 600, height: 600))
        scene.onThingTapped = { [weak self] line in self?.selectLine(line) }
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
        if isRunning { stop() }
        // After a run, the stage still shows what was built, so the hint can build on it.
        let current = result != nil ? (lastWorld ?? world) : world
        if let step = mission.nextStep(in: current) {
            scene.showGhosts(of: step.ghost)
            setGuide(step.text, mood: .curious)
        } else {
            setGuide(GuideVoice.nothingLeftToTry, mood: .delighted)
        }
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
        lastWorld = nil
        codeDidChange()
        setGuide(GuideVoice.freshStart, mood: .calm)
    }

    /// Links a line of code to the things it made. Choosing the same line again clears it.
    func selectLine(_ line: Int?) {
        selectedLine = (line == selectedLine) ? nil : line
        scene.highlightLine(selectedLine)
        if line != nil { haptics.play(.select, enabled: settings.haptics) }
    }

    /// "Look at you go!" the first time the code uses every block this mission offers.
    private func cheerIfAllBlocksUsed() {
        guard !hasCheeredAllBlocks, mission.blocks.count > 1 else { return }
        let markers: [BlockKind: String] = [
            .create: "create(", .build: "build(", .spawn: "spawn(", .summon: "summon(", .launch: "launch(",
            .orbit: "orbit(", .explore: "explore(", .move: "move(", .repeatLoop: "repeat", .condition: "if "
        ]
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
            lastWorld = trace.finalWorld
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

    /// Goes back to editing after a finished run. To The Moon starts from a new universe.
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
            if let note = mission.arrivalNote(for: world) { setGuide(note, mood: .curious, speak: false) }
        }
        fieldIsFresh = true
        scene.load(world)
        stageDescription = world.spokenDescription()
        metGoals = Set(mission.goals.filter { $0.isMet(world) }.map(\.id))
    }

    private var stepDuration: Double {
        // VoiceOver needs time to read each step aloud.
        UIAccessibility.isVoiceOverRunning ? max(speed.stepDuration, RunSpeed.slow.stepDuration) : speed.stepDuration
    }

    private func play(_ trace: Trace, program: [Statement]) async {
        for (index, event) in trace.events.enumerated() {
            let duration = stepDuration * event.kind.pace
            activeLine = event.line
            updateNotes(for: event)
            scene.play(event, duration: duration)
            giveFeedback(for: event)
            react(to: event)
            stageDescription = event.world.spokenDescription()
            metGoals = Set(mission.goals.filter { $0.isMet(event.world) }.map(\.id))

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

    /// The Guiding Light reacts out loud-ish (text only) as new things appear, as surprised as you are.
    private func react(to event: StepEvent) {
        switch event.kind {
        case .created(let body):
            countCommand()
            if seenThings.insert(body.thing).inserted {
                setGuide(GuideVoice.reaction(to: body), mood: .delighted, speak: false)
            }
        case .launched:
            countCommand()
            setGuide(GuideVoice.liftoff, mood: .delighted, speak: false)
        case .orbited(_, _, let createdPlanet):
            countCommand()
            setGuide(createdPlanet ? GuideVoice.orbitMadeAPlanet : GuideVoice.orbiting, mood: .delighted, speak: false)
        case .explored:
            countCommand()
            setGuide(GuideVoice.exploring, mood: .delighted, speak: false)
        case .moved:
            countCommand()
        case .easterEgg(let egg):
            reactToEasterEgg(egg)
        default:
            break
        }
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
        scene.play(StepEvent(line: error.line, kind: .runtimeError(error), world: world), duration: 0.5)
    }

    private func updateNotes(for event: StepEvent) {
        switch event.kind {
        case .loopIterationStarted(let iteration, let total):
            gutterNotes[event.line] = GutterNote(text: "\(iteration)/\(total)", style: .loop)
        case .sensed(_, let result, _):
            gutterNotes[event.line] = GutterNote(text: result ? "yes" : "no", style: result ? .yes : .no)
        default:
            break
        }
    }

    private func giveFeedback(for event: StepEvent) {
        let pan = { (body: Int?) -> Float in
            guard let body else { return 0 }
            return self.scene.horizontalPosition(of: body) * 1.6 - 0.8
        }
        switch event.kind {
        case .created(let body):
            haptics.play(.pop, enabled: settings.haptics)
            let cue: SoundCue = switch body.verb {
            case .create, .spawn: .pop
            case .build: .moveSide
            case .summon: .sparkle
            }
            sound.play(cue, pan: pan(body.id), enabled: settings.sound)
        case .launched(let rockets):
            haptics.play(.launch, enabled: settings.haptics)
            sound.play(.launch, pan: pan(rockets.first), enabled: settings.sound)
        case .orbited(let planet, _, _):
            haptics.play(.loop, enabled: settings.haptics)
            sound.play(.ring, pan: pan(planet.id), enabled: settings.sound)
        case .explored(_, let rovers, _):
            haptics.play(.success, enabled: settings.haptics)
            sound.play(.ping, pan: pan(rovers.first), enabled: settings.sound)
        case .moved(let rockets, let direction):
            haptics.play(.move, enabled: settings.haptics)
            let cue: SoundCue = switch direction {
            case .up: .moveUp
            case .down: .moveDown
            case .left, .right: .moveSide
            }
            sound.play(cue, pan: pan(rockets.first), enabled: settings.sound)
        case .sensed:
            haptics.play(.sense, enabled: settings.haptics)
            sound.play(.ping, enabled: settings.sound)
        case .loopIterationEnded:
            haptics.play(.loop, enabled: settings.haptics)
        case .runtimeError:
            haptics.play(.error, enabled: settings.haptics)
            sound.play(.error, enabled: settings.sound)
        case .easterEgg:
            haptics.play(.success, enabled: settings.haptics)
        case .loopIterationStarted:
            break
        }
        narrator.announce(event.spokenDescription)
    }
}
