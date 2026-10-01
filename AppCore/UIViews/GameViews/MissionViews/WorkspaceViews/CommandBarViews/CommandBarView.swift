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
    let onInsert: (String) -> Void
    let onRun: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            BlockButtonsView(blocks: blocks, onInsert: onInsert)
                .disabled(isRunning)
                .opacity(isRunning ? 0.4 : 1)

            RunButtonView(isRunning: isRunning, onRun: onRun, onStop: onStop)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color.black.opacity(0.75),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .frame(alignment: .center)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}
