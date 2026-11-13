//
//  CreditsView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-16.
//

import SwiftUI

// TODO(Sri): These words are placeholders. Rewrite them in your own voice before submitting.

struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CozyBackground(starCount: 110)

            VStack(spacing: Space.xl) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        IconButtonLabel(systemName: "chevron.left")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Back")
                    Spacer()
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.l)

                Spacer()

                GuidingLightOrb(mood: .calm, size: Space.xxl * 3)
                    .arrive()

                VStack(spacing: Space.s) {
                    Text("Coding in Orbit")
                        .font(Typeface.largeTitle)
                        .foregroundStyle(Color.starlight)
                    Text("Made by Sri Ganty")
                        .font(Typeface.title)
                        .foregroundStyle(Color.goldTrim)
                }
                .arrive(delay: 0.08)

                VStack(spacing: Space.m) {
                    Text("\u{201C}We can build to understand.\u{201D}")
                        .font(Typeface.body.italic())
                        .foregroundStyle(Color.starlight)
                    Text("— Grant Sanderson, 3Blue1Brown")
                        .font(Typeface.caption)
                        .foregroundStyle(Color.starlight.opacity(0.6))
                }
                .multilineTextAlignment(.center)
                .padding(Space.l)
                .cozyPanel()
                .rotationEffect(.degrees(-0.8))
                .arrive(delay: 0.16)

                Text("For everyone who learns by seeing it move.")
                    .font(Typeface.body)
                    .foregroundStyle(Color.starlight.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .arrive(delay: 0.24)

                Text("Built with SwiftUI, SpriteKit, GameplayKit, Core Haptics, and AVFoundation.")
                    .font(Typeface.caption)
                    .foregroundStyle(Color.starlight.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .arrive(delay: 0.3)

                Spacer()
            }
            .padding(.horizontal, Space.xxl)
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    CreditsView()
}
