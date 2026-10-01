//
//  SoundPlayer.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import AVFoundation

// Every sound is generated in code, so the app needs no audio files.
// Sounds also carry information: moving up rises in pitch, moving down falls, and each sound
// pans left or right to follow the rocket. Someone who can't see the screen can hear where
// the rocket is going. Nothing is harsh: errors "boop", wins chime like a music box.

enum SoundCue: CaseIterable {
    case launch, moveUp, moveDown, moveSide, ping, ring, crash, success, error, pop, click, sparkle

    var duration: Double {
        switch self {
        case .launch: 1.3
        case .moveUp, .moveDown, .moveSide: 0.16
        case .ping: 0.35
        case .ring: 0.7
        case .crash: 0.9
        case .success: 1.6
        case .error: 0.4
        case .pop: 0.12
        case .click: 0.06
        case .sparkle: 1.2
        }
    }
}

@MainActor
final class SoundPlayer {
    private let engine = AVAudioEngine()
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0
    private var buffers: [SoundCue: AVAudioPCMBuffer] = [:]
    private var isPrepared = false
    private let ambience = AVAudioPlayerNode()
    private var ambienceBuffer: AVAudioPCMBuffer?

    /// - Parameter pan: -1 is fully left, 1 is fully right.
    func play(_ cue: SoundCue, pan: Float = 0, enabled: Bool) {
        guard enabled, prepareIfNeeded(), let buffer = buffers[cue], !voices.isEmpty else { return }
        // A few player nodes take turns, so overlapping sounds don't cut each other off.
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.pan = max(-1, min(1, pan))
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !voice.isPlaying { voice.play() }
    }

    /// A very quiet, slowly breathing hum, like the hush of an observatory at night.
    func startAmbience(enabled: Bool) {
        guard enabled, prepareIfNeeded(), let ambienceBuffer, !ambience.isPlaying else { return }
        ambience.volume = 0.05
        ambience.scheduleBuffer(ambienceBuffer, at: nil, options: .loops)
        ambience.play()
    }

    func stopAmbience() {
        ambience.stop()
    }

    private func prepareIfNeeded() -> Bool {
        if isPrepared {
            if !engine.isRunning { try? engine.start() }
            return engine.isRunning
        }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else { return false }
        // Ambient: plays alongside the user's music and respects the silent switch.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])

        for _ in 0..<5 {
            let voice = AVAudioPlayerNode()
            engine.attach(voice)
            engine.connect(voice, to: engine.mainMixerNode, format: format)
            voices.append(voice)
        }
        for cue in SoundCue.allCases {
            buffers[cue] = Self.render(cue, format: format)
        }
        engine.attach(ambience)
        engine.connect(ambience, to: engine.mainMixerNode, format: format)
        ambienceBuffer = Self.renderAmbience(format: format)
        do {
            try engine.start()
        } catch {
            return false
        }
        isPrepared = true
        return true
    }

    private static func render(_ cue: SoundCue, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(cue.duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        var synth = Synth(sampleRate: sampleRate)
        for index in 0..<Int(frameCount) {
            let time = Double(index) / sampleRate
            samples[index] = Float(synth.sample(cue, time: time) * 0.3)
        }
        return buffer
    }

    /// Four seconds that loop seamlessly: every frequency fits a whole number of cycles in the loop.
    private static func renderAmbience(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let seconds = 4.0
        let frameCount = AVAudioFrameCount(seconds * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for index in 0..<Int(frameCount) {
            let t = Double(index) / sampleRate
            let breath = 0.6 + 0.4 * Foundation.sin(2 * .pi * 0.25 * t)
            let pad = Foundation.sin(2 * .pi * 110 * t) + 0.6 * Foundation.sin(2 * .pi * 165 * t) + 0.3 * Foundation.sin(2 * .pi * 220.25 * t)
            samples[index] = Float(pad / 1.9 * breath * 0.5)
        }
        return buffer
    }
}

/// A tiny synthesizer. It keeps its phase and filter state between samples so sweeps sound smooth.
private struct Synth {
    let sampleRate: Double
    private var phase = 0.0
    private var filtered = 0.0
    private var seed: UInt32 = 2027

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    mutating func sample(_ cue: SoundCue, time t: Double) -> Double {
        let progress = t / cue.duration
        let attack = min(1, t / 0.005)

        switch cue {
        case .moveUp:
            return sine(520 + 260 * progress) * exp(-progress * 4) * attack
        case .moveDown:
            return sine(440 - 180 * progress) * exp(-progress * 4) * attack
        case .moveSide:
            return sine(480) * exp(-progress * 5) * attack * 0.9
        case .launch:
            let swell = progress < 0.2 ? progress / 0.2 : 1
            let roar = lowpassedNoise(cutoff: 300 + 1500 * progress) * 2.5
            let rumble = Foundation.sin(2 * .pi * (55 + 30 * progress) * t) * 0.4
            return (roar + rumble) * swell * (1 - progress)
        case .ping:
            return (sine(1320) * 0.8 + Foundation.sin(2 * .pi * 1980 * t) * 0.2) * exp(-progress * 6) * attack
        case .ring:
            let chord = [660.0, 880, 1100].reduce(0) { $0 + Foundation.sin(2 * .pi * $1 * t) } / 3
            return chord * exp(-progress * 3) * attack
        case .crash:
            let blast = lowpassedNoise(cutoff: 2500 * (1 - progress) + 200) * 2.2 * exp(-progress * 3)
            let thump = Foundation.sin(2 * .pi * 70 * t) * exp(-progress * 8) * 0.8
            return blast + thump
        case .success:
            // A music-box chime: G, C, E, G, high C, each note ringing with a soft bell overtone.
            return bell(notes: [783.99, 1046.5, 1318.5, 1568, 2093], spacing: 0.12, decay: 3.2, at: t) * 0.9
        case .sparkle:
            // A quick shimmer of high notes for secret surprises.
            return bell(notes: [1568, 2093, 1760, 2637, 2349], spacing: 0.07, decay: 5, at: t) * 0.6
        case .error:
            // A gentle "boop": two soft sine notes sliding down, like a friendly shrug.
            let first = t < 0.16 ? Foundation.sin(2 * .pi * (392 - 60 * t / 0.16) * t) * exp(-t * 14) : 0
            let local = t - 0.16
            let second = local >= 0 ? Foundation.sin(2 * .pi * (294 - 40 * local / 0.24) * local) * exp(-local * 10) : 0
            return (first + second) * attack * 0.8
        case .pop:
            // A soft pop: a quick downward pitch drop, like a bubble.
            return sine(900 - 600 * progress) * exp(-progress * 9) * attack
        case .click:
            // A satisfying click: a short, bright tick with a bit of body.
            return (sine(1800) * 0.5 + lowpassedNoise(cutoff: 4000) * 3) * exp(-progress * 18) * attack
        }
    }

    /// Notes that ring out one after another, each with an overtone that makes it sound like a little bell.
    private func bell(notes: [Double], spacing: Double, decay: Double, at t: Double) -> Double {
        notes.enumerated().reduce(0) { total, note in
            let start = Double(note.offset) * spacing
            guard t >= start else { return total }
            let local = t - start
            let tone = Foundation.sin(2 * .pi * note.element * local) + 0.25 * Foundation.sin(2 * .pi * note.element * 2.76 * local)
            return total + tone * exp(-local * decay) * 0.28 * min(1, local / 0.004)
        }
    }

    private mutating func sine(_ frequency: Double) -> Double {
        phase += 2 * .pi * frequency / sampleRate
        return Foundation.sin(phase)
    }

    private mutating func noise() -> Double {
        seed = seed &* 1_664_525 &+ 1_013_904_223
        return Double(seed) / Double(UInt32.max) * 2 - 1
    }

    private mutating func lowpassedNoise(cutoff: Double) -> Double {
        let smoothing = exp(-2 * .pi * cutoff / sampleRate)
        filtered = smoothing * filtered + (1 - smoothing) * noise()
        return filtered
    }
}
