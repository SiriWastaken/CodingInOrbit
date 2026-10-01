//
//  CommandBarView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-21.
//

import SwiftUI

struct CommandBarView: View {
    let blocks: [Block]
    let isRunning: Bool
    let isReady: Bool
    let onInsert: (String) -> Void
    let onRun: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: Space.m) {
            BlockButtonsView(blocks: blocks, onInsert: onInsert)
                .disabled(isRunning)
                .opacity(isRunning ? 0.4 : 1)
                .animation(.easeInOut(duration: 0.25), value: isRunning)

            RunButtonView(isRunning: isRunning, isReady: isReady, onRun: onRun, onStop: onStop)
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.xs)
        .cozyPanel()
        .padding(.horizontal, Space.m)
        .padding(.bottom, Space.m)
    }
}
