//
//  LineNumberView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-21.
//

import SwiftUI

struct LineNumberView: View {
    let count: Int
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                Text("\(index + 1)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(height: 20)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .background(Color.gray.opacity(0.05))
    }
}
