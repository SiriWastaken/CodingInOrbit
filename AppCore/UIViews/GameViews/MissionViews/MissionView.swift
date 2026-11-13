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
    @AppStorage(MissionProgress.storageKey) private var completedMissions = ""
    @State private var session: GameSession
    @State private var isEditorFocused = false

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
        .transition(.drift)
        .background(CozyBackground(starCount: 40))
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

    @ViewBuilder
    private var header: some View {
        HStack(spacing: Space.m) {
            Button {
                dismiss()
            } label: {
                IconButtonLabel(systemName: "chevron.left")
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Back to missions")

            Spacer()

            VStack(spacing: Space.xs) {
                Text("MISSION \(session.mission.number) · \(session.mission.concept.uppercased())")
                    .font(Typeface.caption)
                    .tracking(2)
                    .foregroundStyle(Color.starlight.opacity(0.55))
                Text(session.mission.title)
                    .font(Typeface.title)
                    .foregroundStyle(Color.starlight)
                ConstellationProgress(total: Mission.all.count,
                                      completed: MissionProgress.completedIDs(from: completedMissions).count,
                                      starSize: Space.m)
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
                IconButtonLabel(systemName: session.speed.icon)
            }
            .menuStyle(.button)
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Run speed")
            .accessibilityValue(session.speed.title)

            Menu {
                Button("Reset Universe", systemImage: "arrow.counterclockwise") {
                    session.stop()
                }
                Button("Restore Starter Code", systemImage: "doc.badge.arrow.up", role: .destructive) {
                    session.restoreStarterCode()
                }
            } label: {
                IconButtonLabel(systemName: "arrow.counterclockwise")
            }
            .menuStyle(.button)
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Reset")
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
        .arrive(from: -Space.l)
    }

    // MARK: - Workspace

    @ViewBuilder
    private var workspace: some View {
        VStack(spacing: 0) {
            GuidingLightView(
                message: session.guideMessage,
                mood: session.guideMood,
                canAdvance: session.hasMoreBriefing,
                onAdvance: { session.advanceBriefing() },
                onHint: { session.showHint() },
                onSpeak: { session.repeatGuide() }
            )
            .padding(Space.m)
            .arrive(delay: 0.05)

            CodeEditorView(
                code: $session.code,
                activeLine: session.activeLine,
                errorLine: session.errorLine,
                selectedLine: session.selectedLine,
                notes: session.gutterNotes,
                isEditable: !session.isRunning,
                bridge: session.editor,
                onEdit: { session.codeDidChange() },
                onLineTapped: { session.selectLine($0) },
                onFocusChange: { focused in isEditorFocused = focused }
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            // The editor glows softly while you're typing in it.
            .overlay(
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(isEditorFocused ? Color.goldTrim.opacity(0.6) : Color.starlight.opacity(0.08), lineWidth: isEditorFocused ? 1.5 : 1)
            )
            .shadow(color: Color.goldTrim.opacity(isEditorFocused ? 0.25 : 0), radius: Space.m)
            .animation(.easeInOut(duration: 0.3), value: isEditorFocused)
            .padding(.horizontal, Space.m)
            .padding(.bottom, Space.s)
            .arrive(delay: 0.12)

            CommandBarView(
                blocks: blocks(for: session.mission.blocks, stage: session.mission.stage),
                isRunning: session.isRunning,
                isReady: session.isCodeReady,
                onInsert: { session.insert($0) },
                onRun: { session.run() },
                onStop: { session.stop() }
            )
            .arrive(delay: 0.2)
        }
    }

    // MARK: - Stage

    @ViewBuilder
    private var stage: some View {
        ZStack(alignment: .bottom) {
            SpriteView(scene: session.scene, preferredFramesPerSecond: 60)
                .accessibilityElement()
                .accessibilityLabel("Your universe")
                .accessibilityValue(session.stageDescription)
                .accessibilityAddTraits(.updatesFrequently)

            GoalChecklistView(goals: session.mission.goals, met: session.metGoals)
                .padding(Space.m)
                .padding(.top, Space.l)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if session.isRunning || session.result != nil {
                OrbitProgressBar(progress: session.runProgress)
                    .padding(.horizontal, Space.xl)
                    .padding(.top, Space.m)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            }

            if let result = session.result {
                MissionResultView(
                    result: result,
                    isMoonMission: session.mission.id == .toTheMoon,
                    nextMission: session.mission.next,
                    onTryAgain: { session.stop() },
                    onNext: { goToNextMission() }
                )
                .padding(Space.l)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .padding(Space.s)
        .animation(systemReduceMotion ? .easeOut(duration: 0.2) : Motion.arrive, value: session.result)
        .animation(.easeInOut(duration: 0.3), value: session.isRunning)
    }

    private func goToNextMission() {
        guard let next = session.mission.next else { return }
        session.leave()
        let nextSession = GameSession(mission: next)
        nextSession.settings = settings
        withAnimation(systemReduceMotion ? .easeOut(duration: 0.2) : Motion.arrive) {
            session = nextSession
        }
        nextSession.start()
    }
}

#Preview {
    MissionView(mission: .liftoff)
        .environmentObject(AccessibilityManager())
}
