//
//  GuidingLightView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI

/// The Guiding Light: a gold orb in the corner of the stage, with a speech bubble above it.
/// Its color follows its mood, but the words always carry the meaning too.
struct GuidingLightView: View {
    let message: String
    let mood: GuideMood
    let canAdvance: Bool
    var canHint = true
    /// First launch only: a little text field to name the rocket.
    var asksForName = false
    var onName: (String) -> Void = { _ in }
    let onAdvance: () -> Void
    let onHint: () -> Void
    let onSpeak: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spins = 0
    @State private var name = ""

    var body: some View {
        VStack(alignment: .trailing, spacing: Space.s) {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(message)
                    .font(Typeface.body)
                    .foregroundStyle(Color.starlight)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(message)
                    .transition(.opacity)

                if asksForName {
                    HStack(spacing: Space.s) {
                        TextField("Rocket name", text: $name)
                            .font(Typeface.body)
                            .foregroundStyle(Color.starlight)
                            .tint(Color.nebulaPurple)
                            .submitLabel(.done)
                            .onSubmit { onName(name) }
                            .padding(.horizontal, Space.m)
                            .frame(minHeight: Tap.minimum)
                            .background(Color.deepSpace, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                        Button("Go") { onName(name) }
                            .buttonStyle(BouncyButtonStyle(kind: .primary, compact: true))
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if canAdvance || canHint {
                    HStack(spacing: Space.s) {
                        if canAdvance {
                            Button("Go on", systemImage: "chevron.right", action: onAdvance)
                        }
                        if canHint {
                            Button("Hint", systemImage: "lightbulb.fill", action: onHint)
                        }
                    }
                    .buttonStyle(BouncyButtonStyle(kind: .secondary, compact: true))
                }
            }
            .padding(Space.m)
            .frame(maxWidth: 360, alignment: .leading)
            .background(Color.midnightBlue.opacity(0.95), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .animation(.easeInOut(duration: 0.3), value: message)

            Button(action: onSpeak) {
                GuidingLightOrb(mood: mood)
                    .keyframeAnimator(initialValue: 0.0, trigger: spins) { content, angle in
                        content.rotationEffect(.degrees(angle))
                    } keyframes: { _ in
                        SpringKeyframe(-12, duration: 0.12)
                        SpringKeyframe(360, duration: 0.6, spring: .bouncy)
                    }
            }
            .buttonStyle(PressableButtonStyle(scale: 0.88))
            .accessibilityLabel("The Guiding Light")
            .accessibilityHint("Reads the message aloud")
        }
        .onChange(of: mood) { _, newMood in
            if newMood == .delighted && !reduceMotion { spins += 1 }
        }
    }
}

/// The orb: a glowing gold light that breathes, growing 5% and back every two seconds.
/// It turns purple when curious and dims when something went wrong.
struct GuidingLightOrb: View {
    let mood: GuideMood
    var size: CGFloat = 60

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color {
        switch mood {
        case .calm, .delighted: .goldTrim
        case .curious: .nebulaPurple
        case .concerned: .starlight.opacity(0.6)
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let breath = 0.5 + 0.5 * sin(time * .pi)
            Circle()
                .fill(RadialGradient(colors: [.starlight, color], center: .center, startRadius: 1, endRadius: size * 0.4))
                .frame(width: size * 0.7, height: size * 0.7)
                // A glow, not a drop shadow: the orb is a light source.
                .shadow(color: color, radius: size * 0.25)
                .frame(width: size, height: size)
                .scaleEffect(1 + 0.05 * breath + (mood == .delighted ? 0.05 : 0))
                .animation(.easeInOut(duration: 0.6), value: mood)
        }
        .frame(minWidth: Tap.minimum, minHeight: Tap.minimum)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: Space.l) {
        GuidingLightView(message: "Oh, hello there! I'm the Guiding Light. I've been watching these stars for a very long time, and I'd love some company.",
                         mood: .calm, canAdvance: true, onAdvance: {}, onHint: {}, onSpeak: {})
        GuidingLightView(message: "Hmm, I don't recognize \"lanch\". Did you mean launch?",
                         mood: .concerned, canAdvance: false, onAdvance: {}, onHint: {}, onSpeak: {})
    }
    .padding()
    .background(CozyBackground())
}
