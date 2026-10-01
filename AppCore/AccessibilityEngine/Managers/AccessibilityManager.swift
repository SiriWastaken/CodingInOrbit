//
//  AccessibilityManager.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-17.
//

import SwiftUI
import Combine

@MainActor
class AccessibilityManager: ObservableObject {
    @AppStorage("isDyslexicFont") var isDyslexicFont = false
    @AppStorage("isHighContrast") var isHighContrast = false
    @AppStorage("isReducedMotion") var isReducedMotion = false
    @AppStorage("isColorBlindMode") var isColorBlindMode = false
    @AppStorage("isDarkMode") var isDarkMode = false
    @AppStorage("isInvertColors") var isInvertColors = false
    @AppStorage("isSpeechEnabled") var isSpeechEnabled = true
    @AppStorage("isHapticsEnabled") var isHapticsEnabled = true
    @AppStorage("isSoundEnabled") var isSoundEnabled = true
    @AppStorage("speechVoice") var speechVoice = "Default"
    @AppStorage("textSizeMultiplier") var textSizeMultiplier: Double = 1.0
    
    @Published var isVoiceOverRunning = false
    
    /// The observatory is always at night. High contrast brightens lines and text within the dark palette instead.
    var effectiveColorScheme: ColorScheme? {
        .dark
    }
    
    init() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // The observer is registered on the main queue, so this always runs on the main actor.
            MainActor.assumeIsolated {
                self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            }
        }
        
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    }
    
    func toggleDyslexicFont() { isDyslexicFont.toggle() }
    func toggleHighContrast() { isHighContrast.toggle() }
    func toggleReducedMotion() { isReducedMotion.toggle() }
    func toggleColorBlindMode() { isColorBlindMode.toggle() }
    func toggleDarkMode() { isDarkMode.toggle() }
    func toggleInvertColors() { isInvertColors.toggle() }
    func toggleSpeech() { isSpeechEnabled.toggle() }
    func toggleHaptics() { isHapticsEnabled.toggle() }
    
    func resetToDefaults() {
        isDyslexicFont = false
        isHighContrast = false
        isReducedMotion = false
        isColorBlindMode = false
        isDarkMode = false
        isInvertColors = false
        isSpeechEnabled = true
        isHapticsEnabled = true
        isSoundEnabled = true
        speechVoice = "Default"
        textSizeMultiplier = 1.0
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
