//
//  BlockButtonsView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-21.
//

import SwiftUI

struct BlockButtonsView: View {
    let onBlockAppended: (Block) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(blocksArray) { block in
                    Button {
                        onBlockAppended(block)
                    } label: {
                        Label(block.title, systemImage: block.icon)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.3))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .scrollDisabled(true)
    }
}
