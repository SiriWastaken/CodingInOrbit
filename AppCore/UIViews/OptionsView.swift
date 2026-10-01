//
//  OptionsView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-16.
//

import SwiftUI

struct OptionsView: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.dismiss) var dismiss

    let speechVoices = ["Default", "British", "Australian"]

    var body: some View {
        ZStack {
            CozyBackground(starCount: 50)

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

                    Text("Options")
                        .font(Typeface.largeTitle)
                        .foregroundStyle(Color.starlight)

                    Spacer()

                    Button {
                        accessibilityManager.resetToDefaults()
                    } label: {
                        IconButtonLabel(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Reset to defaults")
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.l)
                .arrive(from: -Space.l)

                ScrollView {
                    VStack(spacing: Space.xl) {
                        SectionView(title: "How it looks") {
                            Toggle("Dyslexia-friendly font", isOn: $accessibilityManager.isDyslexicFont)
                            Toggle("High contrast", isOn: $accessibilityManager.isHighContrast)
                            Toggle("Color-blind friendly", isOn: $accessibilityManager.isColorBlindMode)
                        }
                        .arrive(delay: 0.05)

                        SectionView(title: "Sound & touch") {
                            Toggle("The Guiding Light speaks", isOn: $accessibilityManager.isSpeechEnabled)
                            Toggle("Sound effects", isOn: $accessibilityManager.isSoundEnabled)
                            Toggle("Haptics", isOn: $accessibilityManager.isHapticsEnabled)

                            VStack(alignment: .leading, spacing: Space.s) {
                                Text("Voice")
                                    .font(Typeface.body)
                                    .foregroundStyle(Color.starlight)
                                ChoiceChips(options: speechVoices, selection: $accessibilityManager.speechVoice)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .arrive(delay: 0.1)

                        SectionView(title: "Motion") {
                            Toggle("Reduce motion", isOn: $accessibilityManager.isReducedMotion)
                        }
                        .arrive(delay: 0.15)

                        SectionView(title: "System") {
                            HStack(spacing: Space.m) {
                                Image(systemName: accessibilityManager.isVoiceOverRunning ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .foregroundStyle(accessibilityManager.isVoiceOverRunning ? Color.goldTrim : Color.starlight.opacity(0.4))
                                Text(accessibilityManager.isVoiceOverRunning ? "VoiceOver is on" : "VoiceOver is off")
                                    .font(Typeface.body)
                                    .foregroundStyle(Color.starlight)
                                Spacer()
                                Button("Open Settings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .buttonStyle(BouncyButtonStyle(kind: .secondary, compact: true))
                            }
                        }
                        .arrive(delay: 0.2)
                    }
                    .toggleStyle(SpaceToggleStyle())
                    .padding(.horizontal, Space.l)
                    .padding(.bottom, Space.xxl)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(title.uppercased())
                .font(Typeface.caption)
                .tracking(2)
                .foregroundStyle(Color.goldTrim.opacity(0.85))
                .padding(.leading, Space.xs)

            VStack(spacing: Space.l) {
                content
            }
            .padding(Space.l)
            .cozyPanel()
        }
    }
}

/// A switch with a starlit knob. When it's on, the track glows gold and a tiny sparkle appears.
struct SpaceToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Space.m) {
            configuration.label
                .font(Typeface.body)
                .foregroundStyle(Color.starlight)
            Spacer()
            Button {
                Feedback.select()
                withAnimation(Motion.press) {
                    configuration.isOn.toggle()
                }
            } label: {
                Capsule()
                    .fill(configuration.isOn ? Color.goldTrim : Color.deepSpace)
                    .overlay(Capsule().strokeBorder(Color.starlight.opacity(configuration.isOn ? 0 : 0.15), lineWidth: 1))
                    .frame(width: Space.xxl + Space.l, height: Space.xxl - Space.xs)
                    .overlay {
                        Circle()
                            .fill(Color.starlight)
                            .overlay {
                                SparkleShape()
                                    .fill(Color.goldTrim)
                                    .padding(Space.s - 1)
                                    .opacity(configuration.isOn ? 1 : 0)
                                    .rotationEffect(.degrees(configuration.isOn ? 0 : -90))
                            }
                            .padding(Space.xs - 1)
                            .shadow(color: Color.deepSpace.opacity(0.4), radius: 2, y: 1)
                            .offset(x: configuration.isOn ? Space.m - 2 : -(Space.m - 2))
                    }
                    .shadow(color: Color.goldTrim.opacity(configuration.isOn ? 0.45 : 0), radius: Space.s)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.9))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAction { configuration.isOn.toggle() }
    }
}

/// A row of pill-shaped choices, used instead of a stock segmented picker.
struct ChoiceChips: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: Space.s) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    Feedback.select()
                    withAnimation(Motion.press) { selection = option }
                } label: {
                    Text(option)
                        .font(Typeface.caption)
                        .foregroundStyle(isSelected ? Color.deepSpace : Color.starlight)
                        .padding(.horizontal, Space.m)
                        .padding(.vertical, Space.s)
                        .background(isSelected ? Color.goldTrim : Color.deepSpace.opacity(0.6), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.goldTrim.opacity(isSelected ? 0 : 0.3), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

#Preview {
    NavigationStack {
        OptionsView()
    }
    .environmentObject(AccessibilityManager())
}
