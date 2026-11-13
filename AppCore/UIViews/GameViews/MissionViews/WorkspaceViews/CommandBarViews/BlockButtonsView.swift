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
            HStack(spacing: Space.s) {
                ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                    BlockChip(block: block, index: index, onInsert: onInsert)
                }
            }
            .padding(.horizontal, Space.xs)
        }
    }
}

/// One block: a quiet outlined chip in code type. Tapping it flashes purple as the code lands.
private struct BlockChip: View {
    let block: Block
    let index: Int
    let onInsert: (String) -> Void

    @State private var isFlashing = false

    var body: some View {
        Group {
            if let only = block.snippets.first, block.snippets.count == 1 {
                Button {
                    add(only.code)
                } label: {
                    chip
                }
                .buttonStyle(PressableButtonStyle(scale: 0.96))
            } else {
                Menu {
                    ForEach(block.snippets) { snippet in
                        Button(snippet.title, systemImage: snippet.icon) {
                            add(snippet.code)
                        }
                    }
                } label: {
                    chip
                }
                .menuStyle(.button)
                .buttonStyle(PressableButtonStyle(scale: 0.96))
                .accessibilityHint("Opens a menu of choices")
            }
        }
        .accessibilityLabel("Insert \(block.title)")
    }

    private func add(_ code: String) {
        onInsert(code)
        isFlashing = true
        withAnimation(.easeOut(duration: 0.15).delay(0.15)) { isFlashing = false }
    }

    private var chip: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
        return Text(block.title.lowercased())
            .font(Typeface.code)
            .foregroundStyle(Color.starlight.opacity(0.8))
            .padding(.horizontal, Space.m)
            .frame(minHeight: Tap.minimum)
            .background(Color.nebulaPurple.opacity(isFlashing ? 0.3 : 0), in: shape)
            .overlay(shape.strokeBorder(Color.starlight.opacity(0.1), lineWidth: 1))
    }
}
