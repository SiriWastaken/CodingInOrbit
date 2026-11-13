//
//  MissionResultView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI

/// The card that slides up over the stage when a flight ends.
struct MissionResultView: View {
    let result: MissionResult
    let isMoonMission: Bool
    let nextMission: Mission?
    let onTryAgain: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                if result.succeeded {
                    SparkleShape()
                        .fill(Color.goldTrim)
                        .frame(width: Space.xl, height: Space.xl)
                        .shadow(color: .goldTrim, radius: Space.s)
                } else {
                    CrescentShape()
                        .fill(Color.ember, style: FillStyle(eoFill: true))
                        .frame(width: Space.xl, height: Space.xl)
                }
                Text(result.title)
                    .font(Typeface.title)
                    .foregroundStyle(result.succeeded ? Color.goldTrim : Color.starlight)
            }
            .accessibilityElement(children: .combine)

            Text(result.message)
                .font(Typeface.body)
                .foregroundStyle(Color.starlight)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Space.s) {
                Button(action: onTryAgain) {
                    Label(isMoonMission ? "New universe" : "Try again", systemImage: isMoonMission ? "sparkles" : "arrow.counterclockwise")
                }
                .buttonStyle(BouncyButtonStyle(kind: .secondary))

                if result.succeeded, let nextMission {
                    Button(action: onNext) {
                        Label("On to \(nextMission.title)", systemImage: "arrow.right")
                    }
                    .buttonStyle(BouncyButtonStyle(kind: .primary))
                }
            }
            .padding(.top, Space.xs)
        }
        .padding(Space.l)
        .frame(maxWidth: 460, alignment: .leading)
        .cozyPanel(cornerRadius: Radius.card)
        .rotationEffect(.degrees(result.succeeded ? -0.8 : 0.6))
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    MissionResultView(result: MissionResult(succeeded: true, title: "Touchdown!", message: "You did it, Commander. The stars are yours."),
                      isMoonMission: false, nextMission: .lowEarthOrbit, onTryAgain: {}, onNext: {})
        .padding()
        .background(CozyBackground())
}
