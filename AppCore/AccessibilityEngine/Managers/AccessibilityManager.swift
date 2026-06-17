//
//  AccessibilityManager.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-17.
//

import SwiftUI
import Combine

class AccessibilityManager: ObservableObject {
    @AppStorage("isDyslexicFont") var isDyslexicFont = false
    @AppStorage("isHighContrast") var isHighContrast = false
    @AppStorage("isReducedMotion") var isReducedMotion = false
    @AppStorage("isColorBlindMode") var isColorBlindMode = false
    @AppStorage("isDarkMode") var isDarkMode = false
    @AppStorage("isInvertColors") var isInvertColors = false
    @AppStorage("isSpeechEnabled") var isSpeechEnabled = true
    @AppStorage("isHapticsEnabled") var isHapticsEnabled = true
    @AppStorage("textSizeMultiplier") var textSizeMultiplier: Double = 1.0
    
    @Published var isVoiceOverRunning = false
    
    var effectiveColorScheme: ColorScheme? {
        if isDarkMode { return .dark }
        if isHighContrast { return .light }
        return nil
    }
    
    init() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
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
        textSizeMultiplier = 1.0
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
