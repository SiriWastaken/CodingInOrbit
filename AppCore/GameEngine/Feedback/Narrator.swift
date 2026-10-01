//
//  Narrator.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import AVFoundation
import UIKit

/// Gives the Guiding Light a voice. With VoiceOver on, it posts announcements instead,
/// so the two voices never talk over each other.
@MainActor
final class Narrator {
    private let synthesizer = AVSpeechSynthesizer()

    /// - Parameter force: Speak even if speech is turned off, because the player asked to hear it.
    func speak(_ text: String, settings: FeedbackSettings, force: Bool = false) {
        if UIAccessibility.isVoiceOverRunning {
            announce(text)
            return
        }
        guard settings.speech || force else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: settings.voiceLanguage)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 0.95
        synthesizer.speak(utterance)
    }

    /// Short updates for VoiceOver users while the code runs.
    func announce(_ text: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
