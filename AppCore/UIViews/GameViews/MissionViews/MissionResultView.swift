//
//  MissionResultView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI

/// The card shown over the stage when a flight ends.
struct MissionResultView: View {
    let result: MissionResult
    let isMoonMission: Bool
    let nextMission: Mission?
    let onTryAgain: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(result.title, systemImage: result.succeeded ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.title3.bold())
                .foregroundStyle(result.succeeded ? .green : .orange)

            Text(result.message)
                .font(.callout)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: onTryAgain) {
                    Label(isMoonMission ? "New Field" : "Try Again", systemImage: isMoonMission ? "dice.fill" : "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .tint(.white)

                if result.succeeded, let nextMission {
                    Button(action: onNext) {
                        Label("Mission \(nextMission.number): \(nextMission.title)", systemImage: "arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .font(.callout.weight(.semibold))
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: 460, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    MissionResultView(result: MissionResult(succeeded: true, title: "Docked!", message: "You reached the space station in 5 moves."),
                      isMoonMission: false, nextMission: .lowEarthOrbit, onTryAgain: {}, onNext: {})
        .padding()
        .background(Color.black)
}
