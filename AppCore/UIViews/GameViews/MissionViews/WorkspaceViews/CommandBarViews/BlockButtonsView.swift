//
//  BlockButtonsView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-21.
//

import SwiftUI

struct BlockButtonsView: View {
    let blocks: [Block]
    let onInsert: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(blocks) { block in
                    // Blocks with one snippet insert it right away; others (like Move) open a menu.
                    if let only = block.snippets.first, block.snippets.count == 1 {
                        Button {
                            onInsert(only.code)
                        } label: {
                            chip(for: block)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Insert \(block.title)")
                    } else {
                        Menu {
                            ForEach(block.snippets) { snippet in
                                Button(snippet.title, systemImage: snippet.icon) {
                                    onInsert(snippet.code)
                                }
                            }
                        } label: {
                            chip(for: block)
                        }
                        .accessibilityLabel("Insert \(block.title)")
                        .accessibilityHint("Opens a menu of choices")
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func chip(for block: Block) -> some View {
        Label(block.title, systemImage: block.icon)
            .font(.callout)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.15))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
            )
    }
}
