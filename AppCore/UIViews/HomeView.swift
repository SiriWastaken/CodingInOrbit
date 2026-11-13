//
//  HomeView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-17.
//

import SwiftUI

struct HomeView: View {
    @StateObject var accessibilityManager = AccessibilityManager()

    var body: some View {
        NavigationStack {
            ZStack {
                CozyBackground(starCount: 90, splashOpacity: 0.2)

                VStack(spacing: Space.xl) {
                    Spacer()

                    FloatingRocket()
                        .frame(width: 120, height: 120)
                        .arrive()

                    VStack(spacing: Space.xs) {
                        Text("Coding in")
                            .font(Typeface.title)
                            .foregroundStyle(Color.starlight.opacity(0.7))
                        Text("Orbit")
                            .font(Typeface.largeTitle)
                            .foregroundStyle(Color.starlight)
                            .shadow(color: Color.goldTrim.opacity(0.35), radius: Space.l)
                    }
                    .accessibilityElement(children: .combine)
                    .arrive(delay: 0.08)

                    Text("Build it. Watch it fly. Understand it.")
                        .font(Typeface.body)
                        .foregroundStyle(Color.starlight.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .arrive(delay: 0.14)

                    VStack(spacing: Space.m) {
                        NavigationLink {
                            InitGameView()
                        } label: {
                            Label("Liftoff", systemImage: "flame.fill")
                                .frame(minWidth: 200)
                                .padding(.vertical, Space.xs)
                        }
                        .buttonStyle(BouncyButtonStyle(kind: .primary))

                        NavigationLink {
                            OptionsView()
                        } label: {
                            Text("Options").frame(minWidth: 200)
                        }
                        .buttonStyle(BouncyButtonStyle(kind: .secondary))

                        NavigationLink {
                            CreditsView()
                        } label: {
                            Text("Credits").frame(minWidth: 200)
                        }
                        .buttonStyle(BouncyButtonStyle(kind: .secondary))
                    }
                    .padding(.top, Space.l)
                    .arrive(delay: 0.22)

                    Spacer()
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

/// The home screen's little doodled rocket, bobbing on a sketchy orbit with its flame flickering.
private struct FloatingRocket: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                OrbitGlyph()
                    .stroke(Color.goldTrim.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .scaleEffect(1.5)
                    .rotationEffect(.degrees(-12))
                RocketGlyph()
                    .stroke(Color.starlight, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .background(RocketGlyph().fill(Color.ember.opacity(0.35)))
                    .shadow(color: Color.goldTrim.opacity(0.4 + 0.2 * sin(time * 9)), radius: Space.s)
                    .rotationEffect(.degrees(8 + 3 * sin(time * 0.8)))
                    .offset(y: sin(time * 1.2) * Double(Space.s))
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HomeView()
}
