//
//  GuidingLightView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI

/// The Guiding Light: a warm, floating orb who explains, encourages, and offers hints.
/// Its color follows its mood: lamplight gold when calm, nebula blue when curious,
/// a brighter gold (with a happy spin) when delighted, and soft ember when something went wrong.
struct GuidingLightView: View {
    let message: String
    let mood: GuideMood
    let canAdvance: Bool
    let onAdvance: () -> Void
    let onHint: () -> Void
    let onSpeak: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spins = 0

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
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

            VStack(alignment: .leading, spacing: Space.s) {
                Text("THE GUIDING LIGHT")
                    .font(Typeface.caption)
                    .tracking(2)
                    .foregroundStyle(Color.goldTrim.opacity(0.85))
                    .accessibilityHidden(true)

                Text(message)
                    .font(Typeface.body)
                    .foregroundStyle(Color.starlight)
                    .lineSpacing(Space.xs / 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(message)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: Space.s)), removal: .opacity))

                HStack(spacing: Space.s) {
                    if canAdvance {
                        Button("Go on", systemImage: "chevron.right", action: onAdvance)
                    }
                    Button("Hint", systemImage: "lightbulb.fill", action: onHint)
                }
                .buttonStyle(BouncyButtonStyle(kind: .secondary, compact: true))
            }
            Spacer(minLength: 0)
        }
        .padding(Space.m)
        .cozyPanel()
        .animation(reduceMotion ? nil : Motion.arrive, value: message)
        .onChange(of: mood) { _, newMood in
            if newMood == .delighted && !reduceMotion { spins += 1 }
        }
    }
}

/// The orb itself: it floats up and down, breathes, and has a tiny star circling it.
struct GuidingLightOrb: View {
    let mood: GuideMood
    var size: CGFloat = Space.xxl * 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color {
        switch mood {
        case .calm, .delighted: .goldTrim
        case .curious: .nebulaBlue
        case .concerned: .ember
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let breath = 0.5 + 0.5 * sin(time * 1.6)
            let float = sin(time * 1.1) * Double(Space.xs)
            let glowBoost = mood == .delighted ? 0.25 : 0

            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [color.opacity(0.5 + glowBoost), .clear], center: .center, startRadius: 2, endRadius: size / 2))
                    .scaleEffect(0.9 + 0.2 * breath + glowBoost)
                Circle()
                    .fill(RadialGradient(colors: [.starlight, color], center: .center, startRadius: 1, endRadius: size * 0.2))
                    .frame(width: size * 0.36, height: size * 0.36)
                    .shadow(color: color, radius: Space.s + Space.xs * breath)
                SparkleShape()
                    .fill(Color.starlight)
                    .frame(width: Space.s + 2, height: Space.s + 2)
                    .offset(x: size * 0.36)
                    .rotationEffect(.radians(time * 0.9))
                    .opacity(0.8)
            }
            .frame(width: size, height: size)
            .offset(y: float)
            .animation(.easeInOut(duration: 0.6), value: mood)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: Space.l) {
        GuidingLightView(message: "Oh, hello there! I'm the Guiding Light. I've been watching these stars for a very long time, and I'd love some company.",
                         mood: .calm, canAdvance: true, onAdvance: {}, onHint: {}, onSpeak: {})
        GuidingLightView(message: "Hmm, I don't recognize \"lanch\". Did you mean launch()?",
                         mood: .concerned, canAdvance: false, onAdvance: {}, onHint: {}, onSpeak: {})
    }
    .padding()
    .background(CozyBackground())
}
