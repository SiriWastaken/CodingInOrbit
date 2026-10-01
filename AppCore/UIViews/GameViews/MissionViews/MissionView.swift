//
//  MissionView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI
import SpriteKit

/// One mission: the Guiding Light and your code on one side, the rocket's world on the other.
/// In landscape the two sit side by side; in portrait the world goes on top.
struct MissionView: View {
    @EnvironmentObject private var accessibilityManager: AccessibilityManager
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var session: GameSession

    init(mission: Mission) {
        _session = State(initialValue: GameSession(mission: mission))
    }

    private var settings: FeedbackSettings {
        accessibilityManager.feedbackSettings(systemReduceMotion: systemReduceMotion)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            GeometryReader { geometry in
                let isWide = geometry.size.width > geometry.size.height
                let layout = isWide ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
                layout {
                    if isWide {
                        workspace.frame(width: geometry.size.width * 0.45)
                        stage
                    } else {
                        stage.frame(height: geometry.size.height * 0.48)
                        workspace
                    }
                }
            }
        }
        .id(session.mission.id)
        .background(Color(red: 0.02, green: 0.03, blue: 0.08).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            session.settings = settings
            session.start()
        }
        .onDisappear {
            session.leave()
        }
        .onChange(of: settings) { _, newValue in
            session.settings = newValue
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Label("Missions", systemImage: "chevron.left")
                    .font(.headline)
            }
            .tint(.white)

            Spacer()

            VStack(spacing: 2) {
                Text("MISSION \(session.mission.number) · \(session.mission.concept.uppercased())")
                    .font(.caption2.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.5))
                Text(session.mission.title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Menu {
                Picker("Speed", selection: $session.speed) {
                    ForEach(RunSpeed.allCases) { speed in
                        Label(speed.title, systemImage: speed.icon).tag(speed)
                    }
                }
            } label: {
                Image(systemName: session.speed.icon)
                    .font(.headline)
            }
            .tint(.white)
            .accessibilityLabel("Run speed")
            .accessibilityValue(session.speed.title)

            Menu {
                Button("Reset Rocket", systemImage: "arrow.counterclockwise") {
                    session.stop()
                }
                Button("Restore Starter Code", systemImage: "doc.badge.arrow.up", role: .destructive) {
                    session.restoreStarterCode()
                }
            } label: {
                Image(systemName: "arrow.counterclockwise.circle")
                    .font(.headline)
            }
            .tint(.white)
            .accessibilityLabel("Reset")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.4))
    }

    // MARK: - Workspace

    private var workspace: some View {
        VStack(spacing: 0) {
            GuidingLightView(
                message: session.guideMessage,
                canAdvance: session.hasMoreBriefing,
                onAdvance: session.advanceBriefing,
                onHint: session.showHint,
                onSpeak: session.repeatGuide
            )
            .padding(12)

            CodeEditorView(
                code: $session.code,
                activeLine: session.activeLine,
                errorLine: session.errorLine,
                selectedLine: session.selectedLine,
                notes: session.gutterNotes,
                isEditable: !session.isRunning,
                bridge: session.editor,
                onEdit: session.codeDidChange,
                onLineTapped: { session.selectLine($0) }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            CommandBarView(
                blocks: blocks(for: session.mission.blocks),
                isRunning: session.isRunning,
                onInsert: session.insert,
                onRun: session.run,
                onStop: session.stop
            )
        }
    }

    // MARK: - Stage

    private var stage: some View {
        ZStack(alignment: .bottom) {
            SpriteView(scene: session.scene, preferredFramesPerSecond: 60)
                .accessibilityElement()
                .accessibilityLabel("Mission map")
                .accessibilityValue(session.stageDescription)
                .accessibilityAddTraits(.updatesFrequently)

            if let result = session.result {
                MissionResultView(
                    result: result,
                    isMoonMission: session.mission.id == .toTheMoon,
                    nextMission: session.mission.next,
                    onTryAgain: { session.stop() },
                    onNext: goToNextMission
                )
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(systemReduceMotion ? nil : .spring(duration: 0.4), value: session.result)
    }

    private func goToNextMission() {
        guard let next = session.mission.next else { return }
        session.leave()
        let nextSession = GameSession(mission: next)
        nextSession.settings = settings
        session = nextSession
        nextSession.start()
    }
}

#Preview {
    MissionView(mission: .liftoff)
        .environmentObject(AccessibilityManager())
}
