//
//  SwiftUIView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-17.
//

import SwiftUI

extension Color {
    static func adaptiveText(_ manager: AccessibilityManager) -> Color {
        if manager.isHighContrast {
            return .white
        }
        return manager.isDarkMode ? .white : .primary
    }
    
    static func adaptiveBackground(_ manager: AccessibilityManager) -> Color {
        if manager.isHighContrast {
            return .black
        }
        return manager.isDarkMode ? Color(red: 0.05, green: 0.05, blue: 0.10) : Color(.systemBackground)
    }
    
    static func adaptiveAccent(_ manager: AccessibilityManager) -> Color {
        if manager.isColorBlindMode {
            return Color.blue
        }
        return Color(red: 0.2, green: 0.4, blue: 0.9)
    }
    
    static func adaptiveSecondary(_ manager: AccessibilityManager) -> Color {
        if manager.isColorBlindMode {
            return Color.gray
        }
        return Color(red: 0.6, green: 0.2, blue: 0.8)
    }
}
