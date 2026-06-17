//
//  SwiftUIView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-16.
//

import SwiftUI

// This screen is the orchestator of the AccessibilityEngine. It's user accessible and...
// it brings together all of AccessibilityManager's functions, as well as options from...
// Accessibility Extensions like ColorAccessibility and ViewAccessibility.
// The technology that makes all of this possible is Apple's Accessibility API. 

struct OptionsView: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @State private var isSplashVisible = true
    @State private var isContentVisible = false
    @State private var selectedSpeechVoice = "Default"
    @Environment(\.dismiss) var dismiss
    
    let speechVoices = ["Default", "British", "Australian"]
    
    var body: some View {
        ZStack {
            Image("SplashScreen")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(
                    Color.black
                        .opacity(0.85)
                        .ignoresSafeArea()
                )
                .opacity(isSplashVisible ? 1 : 0)
                .scaleEffect(isSplashVisible ? 1 : 1.1)
                .animation(.easeOut(duration: 0.5), value: isSplashVisible)
            
            VStack(spacing: 16) {
                HStack {
                    Button{dismiss()} label:{Text("Back")}
                    
                    Text("OPTIONS")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    Spacer()
                    
                    Button {
                        accessibilityManager.resetToDefaults()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .foregroundColor(.yellow)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 40)
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 20) {
                        SectionView(title: "Vision") {
                            Toggle("Dyslexic-Friendly Font", isOn: $accessibilityManager.isDyslexicFont)
                                .toggleStyle(SpaceToggleStyle())
                            
                            Toggle("High Contrast Mode", isOn: $accessibilityManager.isHighContrast)
                                .toggleStyle(SpaceToggleStyle())
                            
                            Toggle("Dark Mode", isOn: $accessibilityManager.isDarkMode)
                                .toggleStyle(SpaceToggleStyle())
                            
                            Toggle("Invert Colors", isOn: $accessibilityManager.isInvertColors)
                                .toggleStyle(SpaceToggleStyle())
                            
                            Toggle("Color-Blind Mode", isOn: $accessibilityManager.isColorBlindMode)
                                .toggleStyle(SpaceToggleStyle())
                        }
                        
                        SectionView(title: "Sound & Haptics") {
                            Toggle("Enable Speech", isOn: $accessibilityManager.isSpeechEnabled)
                                .toggleStyle(SpaceToggleStyle())
                            
                            Toggle("Enable Haptics", isOn: $accessibilityManager.isHapticsEnabled)
                                .toggleStyle(SpaceToggleStyle())
                            
                            Picker("Speech Voice", selection: $selectedSpeechVoice) {
                                ForEach(speechVoices, id: \.self) { voice in
                                    Text(voice).tag(voice)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .colorScheme(.dark)
                        }
                        
                        SectionView(title: "Motion") {
                            Toggle("Reduced Motion", isOn: $accessibilityManager.isReducedMotion)
                                .toggleStyle(SpaceToggleStyle())
                        }
                        
                        SectionView(title: "System Accessibility") {
                            HStack {
                                Image(systemName: accessibilityManager.isVoiceOverRunning ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .foregroundColor(accessibilityManager.isVoiceOverRunning ? .green : .gray)
                                Text(accessibilityManager.isVoiceOverRunning ? "VoiceOver Active" : "VoiceOver Inactive")
                                    .foregroundColor(.white)
                                Spacer()
                                Button("Open Settings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.yellow)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .opacity(isContentVisible ? 1 : 0)
            .offset(y: isContentVisible ? 0 : 30)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: isContentVisible)
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation {
                isSplashVisible = false
                isContentVisible = true
            }
        }
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
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.yellow)
                .padding(.leading, 4)
            
            VStack(spacing: 12) {
                content
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
}

struct SpaceToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .foregroundColor(.white)
            Spacer()
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? Color.yellow : Color.gray.opacity(0.3))
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .padding(3)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.spring(), value: configuration.isOn)
                )
                .onTapGesture {
                    withAnimation(.spring()) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}

extension OptionsView {
    var navigationBarHidden: Bool { true }
}

#Preview {
    OptionsView()
        .environmentObject(AccessibilityManager())
        .preferredColorScheme(.dark)
}
