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
            .padding(.vertical, Space.s)
        }
    }
}

/// One block. Each sits at a slightly different tilt, like cards scattered on a desk,
/// and gives a little wiggle when you add it to your code.
private struct BlockChip: View {
    let block: Block
    let index: Int
    let onInsert: (String) -> Void

    @State private var wiggles = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tilt: Double { [-2, 1.5, -1, 2][index % 4] }

    private var accent: Color {
        switch block.id {
        case .create, .build, .spawn, .summon: .nebulaBlue
        case .launch, .orbit, .explore, .move: .ember
        case .repeatLoop, .condition: .goldTrim
        }
    }

    var body: some View {
        Group {
            if let only = block.snippets.first, block.snippets.count == 1 {
                Button {
                    add(only.code)
                } label: {
                    chip
                }
                .buttonStyle(PressableButtonStyle())
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
                .buttonStyle(PressableButtonStyle())
                .accessibilityHint("Opens a menu of choices")
            }
        }
        .accessibilityLabel("Insert \(block.title)")
    }

    private func add(_ code: String) {
        wiggles += 1
        onInsert(code)
    }

    private var chip: some View {
        let isStill = reduceMotion
        return Label(block.title, systemImage: block.icon)
            .font(Typeface.button)
            .foregroundStyle(Color.starlight)
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.s)
            .background(Color.dusk, in: Capsule())
            .overlay(Capsule().strokeBorder(accent.opacity(0.55), lineWidth: 1.5))
            .shadow(color: Color.deepSpace.opacity(0.5), radius: Space.xs, y: 2)
            .rotationEffect(.degrees(tilt))
            .keyframeAnimator(initialValue: 0.0, trigger: wiggles) { content, angle in
                content.rotationEffect(.degrees(isStill ? 0 : angle))
            } keyframes: { _ in
                SpringKeyframe(-9, duration: 0.08)
                SpringKeyframe(7, duration: 0.1)
                SpringKeyframe(-3, duration: 0.1)
                SpringKeyframe(0, duration: 0.2)
            }
    }
}
