//
//  HapticsPlayer.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import CoreHaptics

// Every command has its own feel, so you can feel your code run: a building rumble for
// launch, a crisp tap for each move, a double ping for a sensor, a hard jolt for a crash.
// (Most iPads don't have a haptic engine, so this quietly does nothing there.)

enum HapticCue {
    case launch, move, sense, loop, crash, success, error, pop, select
}

@MainActor
final class HapticsPlayer {
    private var engine: CHHapticEngine?
    private let isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    func play(_ cue: HapticCue, enabled: Bool) {
        guard enabled, isSupported else { return }
        do {
            let engine = try startedEngine()
            let pattern = try CHHapticPattern(events: events(for: cue), parameterCurves: curves(for: cue))
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are a bonus. If they fail, the mission carries on without them.
        }
    }

    private func startedEngine() throws -> CHHapticEngine {
        let engine = try engine ?? CHHapticEngine()
        engine.isAutoShutdownEnabled = true
        engine.playsHapticsOnly = true
        // The engine shuts itself down when idle, so it's started again before every pattern.
        try engine.start()
        self.engine = engine
        return engine
    }

    private func events(for cue: HapticCue) -> [CHHapticEvent] {
        switch cue {
        case .launch:
            [continuous(at: 0, duration: 1.1, intensity: 0.9, sharpness: 0.25)]
        case .move:
            [transient(at: 0, intensity: 0.55, sharpness: 0.6)]
        case .sense:
            [transient(at: 0, intensity: 0.35, sharpness: 1), transient(at: 0.09, intensity: 0.35, sharpness: 1)]
        case .loop:
            [transient(at: 0, intensity: 0.3, sharpness: 0.3)]
        case .crash:
            [transient(at: 0, intensity: 1, sharpness: 0.8), continuous(at: 0.02, duration: 0.6, intensity: 0.8, sharpness: 0.1)]
        case .success:
            [transient(at: 0, intensity: 0.4, sharpness: 0.5),
             transient(at: 0.12, intensity: 0.6, sharpness: 0.6),
             transient(at: 0.24, intensity: 0.9, sharpness: 0.7),
             continuous(at: 0.3, duration: 0.35, intensity: 0.4, sharpness: 0.3)]
        case .error:
            [transient(at: 0, intensity: 0.45, sharpness: 0.1), transient(at: 0.16, intensity: 0.35, sharpness: 0.1)]
        case .pop:
            [transient(at: 0, intensity: 0.5, sharpness: 0.8)]
        case .select:
            [transient(at: 0, intensity: 0.35, sharpness: 0.5)]
        }
    }

    /// Shapes the continuous parts: launch builds up, a crash fades out.
    private func curves(for cue: HapticCue) -> [CHHapticParameterCurve] {
        let points: [(TimeInterval, Float)] = switch cue {
        case .launch: [(0, 0.2), (0.6, 1), (1.1, 0)]
        case .crash: [(0, 1), (0.6, 0)]
        default: []
        }
        guard !points.isEmpty else { return [] }
        return [CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: points.map { CHHapticParameterCurve.ControlPoint(relativeTime: $0.0, value: $0.1) },
            relativeTime: 0
        )]
    }

    private func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: time)
    }

    private func continuous(at time: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: time, duration: duration)
    }
}
