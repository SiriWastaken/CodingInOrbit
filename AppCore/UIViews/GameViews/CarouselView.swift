//
//  CarouselView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-18.
//

import SwiftUI

struct CarouselView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex = 0
    @State private var isLaunching = false
    @AppStorage(MissionProgress.storageKey) private var completedMissions = ""
    @Namespace private var zoom

    private var completed: Set<String> {
        MissionProgress.completedIDs(from: completedMissions)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    IconButtonLabel(systemName: "chevron.left")
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Back")

                Spacer()

                ConstellationProgress(total: Mission.all.count, completed: completed.count)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Coding in")
                    .font(Typeface.title)
                    .foregroundStyle(Color.starlight.opacity(0.7))
                Text("Orbit")
                    .font(Typeface.largeTitle)
                    .foregroundStyle(Color.starlight)
                Text("Pick a mission. Every one starts with a single line.")
                    .font(Typeface.body)
                    .foregroundStyle(Color.starlight.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.xxl)
            .padding(.vertical, Space.xl)
            .arrive()

            TabView(selection: $selectedIndex) {
                ForEach(Array(Mission.all.enumerated()), id: \.element.id) { index, mission in
                    MissionCard(mission: mission, index: index, isComplete: completed.contains(mission.id.rawValue))
                        .frame(maxWidth: 560)
                        .zoomSource(id: mission.id, in: zoom)
                        .padding(.horizontal, Space.xxl)
                        .padding(.vertical, Space.l)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 400)
            .arrive(delay: 0.1)
            .onChange(of: selectedIndex) { _, _ in Feedback.select() }

            // Page dots, drawn as little sparkles. The current one is gold and a bit bigger.
            HStack(spacing: Space.m) {
                ForEach(Mission.all.indices, id: \.self) { index in
                    SparkleShape()
                        .fill(index == selectedIndex ? Color.goldTrim : Color.starlight.opacity(0.25))
                        .frame(width: index == selectedIndex ? Space.l : Space.s, height: index == selectedIndex ? Space.l : Space.s)
                        .animation(Motion.press, value: selectedIndex)
                }
            }
            .frame(height: Space.l)
            .padding(.bottom, Space.xl)
            .accessibilityHidden(true)

            Button {
                isLaunching = true
            } label: {
                Label("Ignition", systemImage: "flame.fill")
                    .frame(minWidth: 200)
                    .padding(.vertical, Space.xs)
            }
            .buttonStyle(BouncyButtonStyle(kind: .primary))
            .accessibilityHint("Starts Mission \(selectedIndex + 1)")
            .arrive(delay: 0.2)

            Spacer()
        }
        .navigationDestination(isPresented: $isLaunching) {
            let mission = Mission.all[selectedIndex]
            MissionView(mission: mission)
                .zoomTransition(id: mission.id, in: zoom)
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

struct MissionCard: View {
    let mission: Mission
    let index: Int
    let isComplete: Bool

    var body: some View {
        VStack(spacing: Space.l) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.goldTrim.opacity(0.25), .clear], center: .center, startRadius: 4, endRadius: 70))
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(Color.deepSpace.opacity(0.6))
                    .overlay(Circle().strokeBorder(Color.goldTrim.opacity(0.3), lineWidth: 1))
                    .frame(width: 100, height: 100)
                MissionGlyph(mission: mission.id)
                    .frame(width: 52, height: 52)
            }

            VStack(spacing: Space.s) {
                Text("MISSION \(mission.number) · \(mission.concept.uppercased())")
                    .font(Typeface.caption)
                    .tracking(2)
                    .foregroundStyle(Color.goldTrim)

                Text(mission.title)
                    .font(Typeface.largeTitle)
                    .foregroundStyle(Color.starlight)
            }

            Text(mission.summary)
                .font(Typeface.body)
                .foregroundStyle(Color.starlight.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.l)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl)
        .padding(.horizontal, Space.l)
        .cozyPanel(cornerRadius: Radius.card)
        .overlay(alignment: .topTrailing) {
            if isComplete {
                HStack(spacing: Space.xs) {
                    SparkleShape().fill(Color.deepSpace).frame(width: Space.m, height: Space.m)
                    Text("DONE")
                        .font(Typeface.caption)
                        .foregroundStyle(Color.deepSpace)
                }
                .padding(.horizontal, Space.s)
                .padding(.vertical, Space.xs)
                .background(Color.goldTrim, in: Capsule())
                .rotationEffect(.degrees(6))
                .padding(Space.l)
                .accessibilityLabel("Completed")
            }
        }
        // Each card sits at its own slight angle, like postcards pinned to a wall.
        .rotationEffect(.degrees([-1.2, 0.8, -0.6][index % 3]))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        ZStack {
            CozyBackground()
            CarouselView()
        }
    }
    .environmentObject(AccessibilityManager())
}
