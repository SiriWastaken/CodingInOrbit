//
//  SwiftUIView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-16.
//

import SwiftUI

struct InitGameView: View {
    var body: some View {
        ZStack {
            CozyBackground(splashOpacity: 0.16)
            CarouselView()
        }
    }
}

#Preview {
    NavigationStack {
        InitGameView()
    }
    .environmentObject(AccessibilityManager())
}
