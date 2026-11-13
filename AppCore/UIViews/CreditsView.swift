//
//  CreditsView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-16.
//

import SwiftUI

// TODO(Sri): The story, AI note, and asset lines are placeholders. Rewrite them in your own
// voice and make sure they're accurate before submitting.

struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CozyBackground(starCount: 0)

            VStack(spacing: Space.xl) {
                ZStack {
                    Text("Credits")
                        .font(Typeface.title)
                        .foregroundStyle(Color.starlight)
                        .accessibilityAddTraits(.isHeader)
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
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.l)

                Spacer()

                VStack(spacing: Space.l) {
                    Text("Sri Ganty")
                        .font(Typeface.body)
                        .foregroundStyle(Color.starlight)
                    Text("I learn by seeing things move. So I built a universe where every line of code makes something you can watch: a launchpad, a rocket, a moon. If you can see it, you can understand it. This is for everyone who learns that way too.")
                        .font(Typeface.body)
                        .foregroundStyle(Color.starlight.opacity(0.7))
                    Text("Built with help from an AI coding assistant. Every design and teaching decision is my own.")
                        .font(Typeface.caption)
                        .foregroundStyle(Color.starlight.opacity(0.5))
                    Text("Made with SwiftUI, SpriteKit, GameplayKit, Core Haptics, and AVFoundation. Works with VoiceOver, Dynamic Type, and Reduce Motion.")
                        .font(Typeface.caption)
                        .foregroundStyle(Color.starlight.opacity(0.5))
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
                .arrive()

                Spacer()

                Text("Built with SwiftUI and love.")
                    .font(Typeface.caption)
                    .foregroundStyle(Color.starlight.opacity(0.3))
                    .padding(.bottom, Space.l)
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
