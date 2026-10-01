//
//  RunButtonView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-21.
//

import SwiftUI

/// Run, or Stop while the rocket is flying. When the code is ready to go, it breathes with a soft gold glow.
struct RunButtonView: View {
    let isRunning: Bool
    let isReady: Bool
    let onRun: () -> Void
    let onStop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            isRunning ? onStop() : onRun()
        } label: {
            Label(isRunning ? "Stop" : "Run", systemImage: isRunning ? "stop.fill" : "play.fill")
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(BouncyButtonStyle(kind: isRunning ? .ember : .primary))
        .phaseAnimator(isReady && !isRunning && !reduceMotion ? [false, true] : [false]) { content, glowing in
            content.shadow(color: Color.goldTrim.opacity(glowing ? 0.8 : 0), radius: glowing ? Space.l : Space.xs)
        } animation: { _ in
            Motion.breathe
        }
        .keyboardShortcut("r", modifiers: .command)
        .accessibilityHint(isRunning ? "Stops the rocket" : "Runs your code")
    }
}
