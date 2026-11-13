//
//  CarouselView.swift
//  Coding In Orbit
//

import SwiftUI

/// The three acts, one card at a time. Each lesson unlocks the next; finished ones get a check.
/// Once all three are done, Build Anything appears underneath.
struct CarouselView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(MissionProgress.storageKey) private var completedMissions = ""
    @State private var selectedIndex = 0
    @State private var launching: Mission?

    private var completed: Set<String> {
        MissionProgress.completedIDs(from: completedMissions)
    }

    private func isUnlocked(_ index: Int) -> Bool {
        index == 0 || completed.contains(Mission.all[index - 1].id.rawValue)
    }

    var body: some View {
        ZStack {
            CozyBackground(starCount: 20)

            VStack(spacing: Space.l) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        IconButtonLabel(systemName: "chevron.left")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Back")
                    Spacer()
                    NavigationLink {
                        OptionsView()
                    } label: {
                        IconButtonLabel(systemName: "gearshape")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Options")
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.l)

                Spacer()

                TabView(selection: $selectedIndex) {
                    ForEach(Array(Mission.all.enumerated()), id: \.element.id) { index, mission in
                        MissionCard(mission: mission,
                                    isComplete: completed.contains(mission.id.rawValue),
                                    isUnlocked: isUnlocked(index)) {
                            launching = mission
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 380 + Space.xxl)
                .onChange(of: selectedIndex) { _, _ in Feedback.select() }

                HStack(spacing: Space.s) {
                    ForEach(Mission.all.indices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? Color.goldTrim : Color.starlight.opacity(0.2))
                            .frame(width: Space.s, height: Space.s)
                    }
                }
                .animation(Motion.press, value: selectedIndex)
                .accessibilityElement()
                .accessibilityLabel("Lesson \(selectedIndex + 1) of \(Mission.all.count)")

                if completed.isSuperset(of: Mission.all.map(\.id.rawValue)) {
                    Button("Build Anything") { launching = .freePlay }
                        .buttonStyle(BouncyButtonStyle(kind: .secondary))
                        .padding(.top, Space.l)
                }

                Spacer()
            }
        }
        // Coming back from a lesson lands on the next one waiting to be played.
        .onAppear {
            selectedIndex = Mission.all.firstIndex { !completed.contains($0.id.rawValue) } ?? Mission.all.count - 1
        }
        .navigationDestination(item: $launching) { mission in
            MissionView(mission: mission)
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

/// One lesson: icon, name, one line, and Start. Locked lessons show a lock instead.
struct MissionCard: View {
    let mission: Mission
    let isComplete: Bool
    let isUnlocked: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: Space.l) {
            Spacer(minLength: 0)
            Image(systemName: mission.icon)
                .font(.system(size: 72))
                .foregroundStyle(Color.goldTrim.opacity(isUnlocked ? 1 : 0.3))
                .frame(height: 88)
                .overlay(alignment: .topTrailing) {
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(Typeface.title)
                            .foregroundStyle(Color.softTeal)
                            .accessibilityLabel("Completed")
                    }
                }

            Text(mission.title)
                .font(Typeface.title)
                .foregroundStyle(Color.starlight)

            Text(mission.summary)
                .font(Typeface.body)
                .foregroundStyle(Color.starlight.opacity(0.6))
                .lineLimit(2)

            Spacer(minLength: 0)

            Button(action: onStart) {
                Label(isUnlocked ? "Start" : "Locked", systemImage: isUnlocked ? "play.fill" : "lock.fill")
                    .font(Typeface.button)
                    .foregroundStyle(Color.starlight)
                    .frame(width: 160, height: Tap.minimum)
                    .background(Color.nebulaPurple.opacity(isUnlocked ? 1 : 0.3),
                                in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle(scale: 0.96))
            .disabled(!isUnlocked)
            .accessibilityHint(isUnlocked ? "Starts \(mission.title)" : "Finish the lesson before this one first")
        }
        .multilineTextAlignment(.center)
        .padding(Space.xl)
        .frame(width: 300, height: 380)
        .cozyPanel(cornerRadius: Radius.large)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    NavigationStack {
        CarouselView()
    }
    .environmentObject(AccessibilityManager())
}
