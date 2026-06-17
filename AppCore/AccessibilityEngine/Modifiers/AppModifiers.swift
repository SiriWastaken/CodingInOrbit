//
//  AppModifiers.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-17.
//

import SwiftUI

struct AppModifiers: ViewModifier {
    @ObservedObject var accessibilityManager: AccessibilityManager
    
    func body(content: Content) -> some View {
        content
            .font(
                accessibilityManager.isDyslexicFont
                    ? Font.custom("OpenDyslexic", size: 18 * accessibilityManager.textSizeMultiplier)
                    : Font.body
            )
            .preferredColorScheme(accessibilityManager.effectiveColorScheme)
            .animation(accessibilityManager.isReducedMotion ? nil : .default, value: accessibilityManager.isDarkMode)
    }
}

extension View {
    func applyAccessibility(_ manager: AccessibilityManager) -> some View {
        self.modifier(AppModifiers(accessibilityManager: manager))
    }
}
