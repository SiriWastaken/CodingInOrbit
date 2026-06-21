//
//  CommandBarView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-21.
//

import SwiftUI

struct CommandBarView: View {
    @Binding var codeLines: [CodeLine]
    let onRun: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            BlockButtonsView { block in
                appendBlock(block)
            }
            
            RunButtonView(onRun: onRun)
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
    
    private func appendBlock(_ block: Block) {
        let newLine = CodeLine(depth: 0, text: block.command + "()")
        codeLines.append(newLine)
    }
}
