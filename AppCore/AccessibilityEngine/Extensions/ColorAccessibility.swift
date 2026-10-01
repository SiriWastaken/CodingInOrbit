//
//  SwiftUIView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-17.
//

import SwiftUI

// Accessibility-aware colors, all drawn from the app's palette (see Theme.swift).

@MainActor
extension Color {
    static func adaptiveText(_ manager: AccessibilityManager) -> Color {
        manager.isHighContrast ? .starlight : .starlight.opacity(0.85)
    }

    static func adaptiveBackground(_ manager: AccessibilityManager) -> Color {
        manager.isHighContrast ? .deepSpace : .dusk
    }

    static func adaptiveAccent(_ manager: AccessibilityManager) -> Color {
        manager.isColorBlindMode ? .nebulaBlue : .goldTrim
    }

    static func adaptiveSecondary(_ manager: AccessibilityManager) -> Color {
        manager.isColorBlindMode ? .starlight.opacity(0.6) : .ember
    }
}
