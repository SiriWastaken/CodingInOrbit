//
//  HomeView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-17.
//

import SwiftUI

/// The title page: the rocket, the name, and Liftoff. Options and Credits wait quietly below.
struct HomeView: View {
    @StateObject var accessibilityManager = AccessibilityManager()

    var body: some View {
        NavigationStack {
            ZStack {
                CozyBackground(starCount: 15, showsSplash: true)

                VStack(spacing: Space.xl) {
                    Spacer()

                    FloatingRocket()
                        .frame(width: 120, height: 120)
                        .arrive()

                    Text("Coding in Orbit")
                        .font(Typeface.hero)
                        .foregroundStyle(Color.starlight)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .arrive(delay: 0.08)

                    VStack(spacing: Space.m) {
                        NavigationLink {
                            CarouselView()
                        } label: {
                            Text("Liftoff").frame(width: 280 - Space.xl * 2)
                        }
                        .buttonStyle(BouncyButtonStyle(kind: .primary))

                        NavigationLink {
                            OptionsView()
                        } label: {
                            Text("Options").frame(width: 280 - Space.xl * 2)
                        }
                        .buttonStyle(BouncyButtonStyle(kind: .secondary))

                        NavigationLink {
                            CreditsView()
                        } label: {
                            Text("Credits").frame(width: 280 - Space.xl * 2)
                        }
                        .buttonStyle(BouncyButtonStyle(kind: .secondary))
                    }
                    .padding(.top, Space.l)
                    .arrive(delay: 0.16)

                    Spacer()

                    Text("Built for the Swift Student Challenge 2027.")
                        .font(Typeface.caption)
                        .foregroundStyle(Color.starlight.opacity(0.4))
                        .padding(.bottom, Space.l)
                }
                .padding(.horizontal, Space.xxl)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .environmentObject(accessibilityManager)
        .applyAccessibility(accessibilityManager)
        .preferredColorScheme(.dark)
    }
}

/// The title page's rocket, bobbing gently with its flame flickering.
private struct FloatingRocket: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            RocketGlyph()
                .stroke(Color.starlight, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .background(RocketGlyph().fill(Color.nebulaPurple))
                .rotationEffect(.degrees(8 + 3 * sin(time * 0.8)))
                .offset(y: sin(time * .pi) * Double(Space.xs))
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HomeView()
}
