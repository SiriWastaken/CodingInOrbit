//
//  FeedbackSettings.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI

/// How the scene should look, based on the player's accessibility choices.
struct SceneStyle: Equatable, Sendable {
    var reduceMotion = false
    var highContrast = false
    var colorBlind = false
}

/// A snapshot of the Options screen, handed to the GameSession so it knows how to give feedback.
struct FeedbackSettings: Equatable, Sendable {
    var haptics = true
    var sound = true
    var speech = true
    /// A BCP 47 language code like "en-GB", or nil for the device's default voice.
    var voiceLanguage: String?
    var style = SceneStyle()
}

extension AccessibilityManager {
    func feedbackSettings(systemReduceMotion: Bool) -> FeedbackSettings {
        let voiceLanguage: String? = switch speechVoice {
        case "British": "en-GB"
        case "Australian": "en-AU"
        default: nil
        }
        return FeedbackSettings(
            haptics: isHapticsEnabled,
            sound: isSoundEnabled,
            speech: isSpeechEnabled,
            voiceLanguage: voiceLanguage,
            style: SceneStyle(
                reduceMotion: isReducedMotion || systemReduceMotion,
                highContrast: isHighContrast,
                colorBlind: isColorBlindMode
            )
        )
    }
}
