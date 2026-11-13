//
//  RunButtonView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-21.
//

import SwiftUI

/// Run, or Stop while the rocket is flying. Run is the only filled thing in the command bar.
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
                .frame(minWidth: 80 - Space.xl * 2)
        }
        .buttonStyle(BouncyButtonStyle(kind: isRunning ? .secondary : .run))
        // When the code is ready, the play icon gently pulses.
        .symbolEffect(.pulse, isActive: isReady && !isRunning && !reduceMotion)
        .keyboardShortcut("r", modifiers: .command)
        .accessibilityHint(isRunning ? "Stops the rocket" : "Runs your code")
    }
}
