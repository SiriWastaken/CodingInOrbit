//
//  BlockButtonsView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-21.
//

import SwiftUI

struct BlockButtonsView: View {
    let onBlockTapped: (Block) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(blocksArray) { block in
                    Button {
                        onBlockTapped(block)
                    } label: {
                        Label(block.title, systemImage: block.icon)
                            .font(.callout)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
