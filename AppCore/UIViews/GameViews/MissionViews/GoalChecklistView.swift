//
//  GoalChecklistView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-10-01.
//

import SwiftUI

/// What this part of the universe still needs, floating over the stage. Each chip lights up
/// the moment your code makes it true, so you can watch the world fill in.
struct GoalChecklistView: View {
    let goals: [Goal]
    let met: Set<String>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            ForEach(goals) { goal in
                let done = met.contains(goal.id)
                HStack(spacing: Space.xs) {
                    Image(systemName: done ? "checkmark.circle.fill" : goal.icon)
                        .foregroundStyle(done ? Color.goldTrim : Color.starlight.opacity(0.5))
                        .contentTransition(.symbolEffect(.replace))
                    Text(goal.title)
                        .foregroundStyle(done ? Color.starlight : Color.starlight.opacity(0.55))
                }
                .font(Typeface.caption)
                .padding(.horizontal, Space.s)
                .padding(.vertical, Space.xs)
                .background(Capsule().fill(Color.deepSpace.opacity(done ? 0.85 : 0.55)))
                .overlay(Capsule().strokeBorder(Color.goldTrim.opacity(done ? 0.8 : 0), lineWidth: 1))
                .scaleEffect(done && !reduceMotion ? 1.0 : 0.97, anchor: .leading)
                .animation(reduceMotion ? nil : Motion.press, value: done)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(goal.title), \(done ? "done" : "not yet")")
            }
        }
        .animation(reduceMotion ? nil : Motion.arrive, value: goals.count)
    }
}

#Preview {
    GoalChecklistView(goals: Mission.liftoff.goals, met: ["liftoff"])
        .padding()
        .background(CozyBackground())
}
