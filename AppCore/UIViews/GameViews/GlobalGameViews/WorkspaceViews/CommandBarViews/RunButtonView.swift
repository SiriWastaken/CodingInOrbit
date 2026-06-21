//
//  RunButtonView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-21.
//

import SwiftUI

struct RunButtonView: View {
    let onRun: () -> Void
    
    var body: some View {
        Button {
            onRun()
        } label: {
            Label("Run", systemImage: "play.fill")
                .font(.callout)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
