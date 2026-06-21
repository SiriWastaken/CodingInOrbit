//
//  RunButtonView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-21.
//

import SwiftUI

struct RunButtonView: View {
    let codeLines: [CodeLine]
    
    var body: some View {
        HStack {
            Spacer()
            Button("▶ Run") {
                print("Executing code:")
                codeLines.forEach { print(String(repeating: "  ", count: $0.depth) + $0.text) }
            }
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.3))
            .cornerRadius(8)
            .padding(8)
        }
    }
}
