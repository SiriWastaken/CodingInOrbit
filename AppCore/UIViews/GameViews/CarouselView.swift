//
//  CarouselView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-18.
//

import SwiftUI

struct Lesson: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    let description: String
}

let lessons: [Lesson] = [
    Lesson(
        title: "Tutorial",
        icon: "graduationcap.fill",
        description: "Learn to code by guiding a rocket through space."
    )
]

struct CarouselView: View {
    @State private var selectedIndex = 0
    @State private var isLaunching = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.03, blue: 0.08),
                        Color(red: 0.04, green: 0.06, blue: 0.15),
                        Color(red: 0.02, green: 0.03, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .overlay(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 100,
                        endRadius: 500
                    )
                )

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CODING IN")
                            .font(.system(size: 18, weight: .light, design: .serif))
                            .tracking(4)
                            .foregroundStyle(.white.opacity(0.6))

                        Text("ORBIT")
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .tracking(6)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)
                    .padding(.top, 40)
                    .padding(.bottom, 8)

                    Text("MISSIONS")
                        .font(.system(size: 11, weight: .light))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 24)

                    TabView(selection: $selectedIndex) {
                        ForEach(0..<lessons.count, id: \.self) { index in
                            MissionCard(lesson: lessons[index])
                                .tag(index)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 8)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 360)
                    .padding(.bottom, 12)

                    HStack(spacing: 10) {
                        ForEach(0..<lessons.count, id: \.self) { index in
                            Circle()
                                .fill(index == selectedIndex ? Color.blue : Color.white.opacity(0.2))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut(duration: 0.2), value: selectedIndex)
                        }
                    }
                    .padding(.bottom, 24)

                    Button {
                        isLaunching = true
                    } label: {
                        Text("LAUNCH MISSION")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .tracking(2)
                            .foregroundStyle(.white)
                            .frame(width: 260, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color(red: 0.3, green: 0.2, blue: 0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .blue.opacity(0.3), radius: 16, x: 0, y: 6)
                    }
                    .padding(.bottom, 40)

                    Spacer()
                }
            }
            .navigationDestination(isPresented: $isLaunching) {
                GlobalGameView()
                    .navigationBarHidden(true)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct MissionCard: View {
    let lesson: Lesson

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.black.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                    )

                Image(systemName: lesson.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .blue.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Text(lesson.title)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text(lesson.description)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

#Preview {
    CarouselView()
}
