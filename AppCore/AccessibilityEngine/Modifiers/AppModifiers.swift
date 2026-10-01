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
            .font(Font.appBody(accessibilityManager))
            .preferredColorScheme(accessibilityManager.effectiveColorScheme)
            .animation(accessibilityManager.isReducedMotion ? nil : .default, value: accessibilityManager.isDarkMode)
    }
}

extension Font {
    /// The OpenDyslexic font when it's turned on and bundled with the app. Without the font file,
    /// it falls back to the rounded system font, which many dyslexic readers also find easier.
    /// Both scale with Dynamic Type.
    @MainActor
    static func appBody(_ manager: AccessibilityManager) -> Font {
        guard manager.isDyslexicFont else { return .body }
        if UIFont(name: "OpenDyslexic", size: 17) != nil {
            return .custom("OpenDyslexic", size: 18 * manager.textSizeMultiplier, relativeTo: .body)
        }
        return .system(.body, design: .rounded)
    }
}

extension View {
    func applyAccessibility(_ manager: AccessibilityManager) -> some View {
        self.modifier(AppModifiers(accessibilityManager: manager))
    }
}
