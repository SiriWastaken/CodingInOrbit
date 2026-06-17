//
//  ViewAccessibility.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-17.
//

import SwiftUI

extension View {
    func accessibleLabel(_ label: String) -> some View {
        self.accessibilityLabel(label)
    }
    
    func accessibleHint(_ hint: String) -> some View {
        self.accessibilityHint(hint)
    }
    
    func accessibleAddTraits(_ traits: AccessibilityTraits) -> some View {
        self.accessibilityAddTraits(traits)
    }
    
    func accessibleRemoveTraits(_ traits: AccessibilityTraits) -> some View {
        self.accessibilityRemoveTraits(traits)
    }
    
    // FIXED: accessibilityAction requires a named parameter
    func accessibleAction(named name: String = "Activate", action: @escaping () -> Void) -> some View {
        self.accessibilityAction(named: name) {
            action()
        }
    }
    
    func applyDyslexicFont(_ manager: AccessibilityManager) -> some View {
        self.font(
            manager.isDyslexicFont
                ? Font.custom("OpenDyslexic", size: 18 * manager.textSizeMultiplier)
                : Font.body
        )
    }
}
