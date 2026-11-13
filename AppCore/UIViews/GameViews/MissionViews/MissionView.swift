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
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss
    @State private var session: GameSession
    /// Set a few seconds after the last lesson is won.
    @State private var showsEnding = false

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
                // Side by side when there's room (a regular-width size class, or any wide window).
                let isWide = sizeClass == .regular || geometry.size.width > geometry.size.height
                let layout = isWide ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
                layout {
                    if isWide {
                        workspace.frame(width: geometry.size.width * 0.45)
                        stage.ignoresSafeArea(.keyboard)
                    } else {
                        stage.frame(height: geometry.size.height * 0.48).ignoresSafeArea(.keyboard)
                        workspace
                    }
                }
            }
        }
        .overlay {
            if showsEnding {
                EndingView(onBuildAnything: { switchTo(.freePlay) }, onBackToStart: { dismiss() })
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showsEnding)
        // After a win, the reward plays out on stage for a few seconds. Then the Moon rolls
        // the ending, and the other lessons head back to the carousel with the next one unlocked.
        .task(id: session.result) {
            guard session.result?.succeeded == true else { return }
            if session.mission.id == .moon {
                // Touchdown, then the astronaut's walk (about 3.5s), the Guiding Light's last word, and the ending.
                guard (try? await Task.sleep(for: .seconds(3.6))) != nil else { return }
                session.sayFinale()
                guard (try? await Task.sleep(for: .seconds(1.8))) != nil else { return }
                showsEnding = true
                session.celebrateEnding()
            } else {
                guard (try? await Task.sleep(for: .seconds(2))) != nil else { return }
                dismiss()
            }
        }
        .id(session.mission.id)
        .transition(.opacity)
        .background(CozyBackground(starCount: 20))
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

    // MARK: - Top bar

    /// Just quiet icons: back to the lessons, start over, and the gear for Options.
    @ViewBuilder
    private var header: some View {
        HStack(spacing: Space.s) {
            Button {
                dismiss()
            } label: {
                IconButtonLabel(systemName: "chevron.left")
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Back")

            Spacer()
            Button {
                session.restoreStarterCode()
            } label: {
                IconButtonLabel(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Start over")

            NavigationLink {
                OptionsView()
            } label: {
                IconButtonLabel(systemName: "gearshape")
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Options")
        }
        .padding(.horizontal, Space.l)
    }

    // MARK: - Workspace

    @ViewBuilder
    private var workspace: some View {
        VStack(spacing: 0) {
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
                onFocusChange: { _ in }
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .padding(.horizontal, Space.m)
            .padding(.top, Space.m)
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
        .background(Color.midnightBlue)
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

            if !session.mission.goals.isEmpty {
                GoalChecklistView(goals: session.mission.goals, met: session.metGoals)
                    .padding(Space.m)
                    .padding(.top, Space.l)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if session.isRunning || session.result != nil {
                OrbitProgressBar(progress: session.runProgress)
                    .padding(.horizontal, Space.xl)
                    .padding(.top, Space.m)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            }

            GuidingLightView(
                message: session.guideMessage,
                mood: session.guideMood,
                canAdvance: session.hasMoreBriefing,
                canHint: !session.isFreePlay && !session.needsRocketName,
                asksForName: session.needsRocketName,
                onName: { session.nameRocket($0) },
                onAdvance: { session.advanceBriefing() },
                onHint: { session.showHint() },
                onSpeak: { session.repeatGuide() }
            )
            .padding(Space.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .arrive(delay: 0.05)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .padding(Space.s)
        .animation(systemReduceMotion ? .easeOut(duration: 0.2) : Motion.arrive, value: session.result)
        .animation(.easeInOut(duration: 0.3), value: session.isRunning)
    }

    private func switchTo(_ next: Mission) {
        showsEnding = false
        session.leave()
        let nextSession = GameSession(mission: next)
        nextSession.settings = settings
        withAnimation(.easeInOut(duration: 0.3)) {
            session = nextSession
        }
        nextSession.start()
    }
}

#Preview {
    MissionView(mission: .liftoff)
        .environmentObject(AccessibilityManager())
}
