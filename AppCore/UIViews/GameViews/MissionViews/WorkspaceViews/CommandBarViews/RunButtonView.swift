//
//  RunButtonView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-21.
//

import SwiftUI

struct RunButtonView: View {
    let isRunning: Bool
    let onRun: () -> Void
    let onStop: () -> Void

    private var tint: Color { isRunning ? .red : .green }

    var body: some View {
        Button {
            isRunning ? onStop() : onRun()
        } label: {
            Label(isRunning ? "Stop" : "Run", systemImage: isRunning ? "stop.fill" : "play.fill")
                .font(.callout)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(color: tint.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("r", modifiers: .command)
        .accessibilityHint(isRunning ? "Stops the rocket" : "Runs your code")
    }
}
