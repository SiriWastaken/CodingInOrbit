//
//  EndingView.swift
//  Coding In Orbit
//

import SwiftUI

/// The finale, after landing on the Moon. More stars than anywhere else in the app,
/// the rocket spins for joy three times, gold bursts out from the middle, and the sky opens up.
struct EndingView: View {
    let onBuildAnything: () -> Void
    let onBackToStart: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasBurst = false
    @State private var spin = 0.0

    var body: some View {
        ZStack {
            CozyBackground(starCount: 50)
            burst

            VStack(spacing: Space.xl) {
                Spacer()

                RocketGlyph()
                    .stroke(Color.starlight, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .background(RocketGlyph().fill(Color.nebulaPurple))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(spin))
                    .accessibilityHidden(true)

                VStack(spacing: Space.s) {
                    Text("You did it, Commander.")
                        .font(Typeface.largeTitle)
                        .foregroundStyle(Color.starlight)
                    Text("The universe is yours.")
                        .font(Typeface.title)
                        .foregroundStyle(Color.goldTrim)
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                Spacer()

                HStack(spacing: Space.m) {
                    Button(action: onBuildAnything) {
                        Text("Build Anything").frame(width: 200 - Space.xl * 2)
                    }
                    .buttonStyle(BouncyButtonStyle(kind: .primary))

                    Button(action: onBackToStart) {
                        Text("Back to Start").frame(width: 200 - Space.xl * 2, height: 56)
                    }
                    .buttonStyle(BouncyButtonStyle(kind: .secondary))
                }
                .padding(.bottom, Space.xxl)
            }
            .padding(.horizontal, Space.xl)
        }
        .onAppear {
            Feedback.tap(.heavy)
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.5)) { hasBurst = true }
            withAnimation(.easeInOut(duration: 2).repeatCount(3, autoreverses: false)) { spin = 360 }
        }
    }

    /// Gold sparks fly out from behind the rocket and fade over a second and a half.
    private var burst: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { index in
                let angle = Double(index) / 24 * 2 * .pi
                let distance = hasBurst ? Space.xxl * CGFloat(4 + (index % 3) * 2) : 0
                SparkleShape()
                    .fill(Color.goldTrim)
                    .frame(width: Space.m, height: Space.m)
                    .offset(x: cos(angle) * distance, y: sin(angle) * distance - Space.xxl * 2)
                    .opacity(hasBurst ? 0 : 1)
            }
        }
        .opacity(reduceMotion ? 0 : 1)
        .accessibilityHidden(true)
    }
}

#Preview {
    EndingView(onBuildAnything: {}, onBackToStart: {})
}
