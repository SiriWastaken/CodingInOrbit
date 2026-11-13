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
            CozyBackground(starCount: 0)

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
                        .font(Typeface.title)
                        .foregroundStyle(Color.starlight)

                    Spacer()

                    Button("Reset") {
                        accessibilityManager.resetToDefaults()
                    }
                    .font(Typeface.caption)
                    .foregroundStyle(Color.starlight.opacity(0.6))
                    .frame(minWidth: Tap.minimum, minHeight: Tap.minimum)
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Reset to defaults")
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.l)

                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xl) {
                        SectionView(title: "Look") {
                            Toggle("Dyslexia-friendly font", isOn: $accessibilityManager.isDyslexicFont)
                            Toggle("High contrast", isOn: $accessibilityManager.isHighContrast)
                            Toggle("Color-blind friendly", isOn: $accessibilityManager.isColorBlindMode)
                        }

                        SectionView(title: "Sound & touch") {
                            Toggle("Read aloud", isOn: $accessibilityManager.isSpeechEnabled)
                            Toggle("Sound effects", isOn: $accessibilityManager.isSoundEnabled)
                            Toggle("Haptics", isOn: $accessibilityManager.isHapticsEnabled)
                            HStack {
                                Text("Voice")
                                    .font(Typeface.body)
                                    .foregroundStyle(Color.starlight)
                                Spacer()
                                ChoiceChips(options: speechVoices, selection: $accessibilityManager.speechVoice)
                            }
                        }

                        SectionView(title: "Motion") {
                            Toggle("Reduce motion", isOn: $accessibilityManager.isReducedMotion)
                        }

                        NavigationLink {
                            CreditsView()
                        } label: {
                            Text("Credits")
                        }
                        .buttonStyle(BouncyButtonStyle(kind: .secondary))
                    }
                    .toggleStyle(SpaceToggleStyle())
                    .frame(maxWidth: 560)
                    .padding(.horizontal, Space.xl)
                    .padding(.bottom, Space.xxl)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

/// A caption header and plain rows. No card behind it.
struct SectionView<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(Typeface.caption)
                .tracking(2)
                .foregroundStyle(Color.starlight.opacity(0.4))
                .padding(.bottom, Space.xs)
                .accessibilityAddTraits(.isHeader)
            content
                .frame(minHeight: Tap.minimum)
        }
    }
}

/// A 50 by 30 switch: purple when on, faint when off. The thumb's side says the state too,
/// so color is never the only clue.
struct SpaceToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            Feedback.tap(.light)
            withAnimation(Motion.toggle) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: Space.m) {
                configuration.label
                    .font(Typeface.body)
                    .foregroundStyle(Color.starlight)
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? Color.nebulaPurple : Color.starlight.opacity(0.2))
                    .frame(width: 50, height: 30)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color.starlight)
                            .frame(width: 24, height: 24)
                            .padding(3)
                    }
            }
            .frame(minHeight: Tap.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

/// A row of words. The chosen one is bright with a gold underline.
struct ChoiceChips: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: Space.l) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    Feedback.select()
                    withAnimation(Motion.press) { selection = option }
                } label: {
                    Text(option)
                        .font(Typeface.body)
                        .foregroundStyle(Color.starlight.opacity(isSelected ? 1 : 0.5))
                        .padding(.bottom, Space.xs)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.goldTrim).frame(height: 2).opacity(isSelected ? 1 : 0)
                        }
                        .frame(minHeight: Tap.minimum)
                }
                .buttonStyle(.plain)
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
