//
//  GuidingLightView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI

/// The Guiding Light: a warm, glowing guide who explains, encourages, and offers hints.
struct GuidingLightView: View {
    let message: String
    let canAdvance: Bool
    let onAdvance: () -> Void
    let onHint: () -> Void
    let onSpeak: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isGlowing = false

    static let gold = Color(red: 1, green: 0.82, blue: 0.45)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onSpeak) {
                orb
            }
            .buttonStyle(.plain)
            .accessibilityLabel("The Guiding Light")
            .accessibilityHint("Reads the message aloud")

            VStack(alignment: .leading, spacing: 8) {
                Text("THE GUIDING LIGHT")
                    .font(.caption2.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Self.gold.opacity(0.85))
                    .accessibilityHidden(true)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(message)
                    .transition(.opacity)

                HStack(spacing: 8) {
                    if canAdvance {
                        Button("Next", systemImage: "chevron.right", action: onAdvance)
                    }
                    Button("Hint", systemImage: "lightbulb.fill", action: onHint)
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(Self.gold)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Self.gold.opacity(0.15), lineWidth: 1))
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: message)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }

    private var orb: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Self.gold.opacity(0.55), .clear], center: .center, startRadius: 2, endRadius: 30))
                .frame(width: 60, height: 60)
                .scaleEffect(isGlowing ? 1.15 : 0.9)
            Circle()
                .fill(RadialGradient(colors: [.white, Self.gold], center: .center, startRadius: 1, endRadius: 12))
                .frame(width: 22, height: 22)
                .shadow(color: Self.gold, radius: isGlowing ? 14 : 8)
        }
        .frame(width: 60, height: 60)
    }
}

#Preview {
    GuidingLightView(message: "Hello, explorer. I'm the Guiding Light, and I'll be with you on every mission.",
                     canAdvance: true, onAdvance: {}, onHint: {}, onSpeak: {})
        .padding()
        .background(Color.black)
}
