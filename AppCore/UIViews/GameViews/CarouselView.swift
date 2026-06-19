//
//  Sidebar.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-18.
//

import SwiftUI

struct Lesson: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
}

let lessons: [Lesson] = [
    Lesson(title: "Liftoff", icon: "paperplane.fill"),
    Lesson(title: "Low Earth Orbit", icon: "globe.americas.fill"),
    Lesson(title: "Travel To The Moon", icon: "moon.stars.fill")
]

struct SidebarView: View {
    @State private var selectedLesson: Lesson? = lessons.first

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            contentView
        } detail: {
            EmptyView()
        }
        .navigationSplitViewColumnWidth(
            min: 280,
            ideal: 320,
            max: 360
        )
        .preferredColorScheme(.dark)
    }


    private var sidebar: some View {
        ZStack {
            spaceBackground

            VStack(spacing: 0) {

                VStack(spacing: 2) {
                    Text("CODING IN")
                        .font(.system(size: 16, weight: .light, design: .serif))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.7))

                    Text("ORBIT")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .tracking(6)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 18)
                .padding(.horizontal)


                List {
                    Section("MISSIONS") {
                        ForEach(lessons) { lesson in
                            LessonRow(
                                lesson: lesson,
                                isSelected: selectedLesson == lesson
                            )
                            .tag(lesson)
                            .onTapGesture {
                                selectedLesson = lesson
                            }
                            .listRowInsets(
                                EdgeInsets(
                                    top: 6,
                                    leading: 12,
                                    bottom: 6,
                                    trailing: 12
                                )
                            )
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)

                Spacer(minLength: 0)
            }
        }
    }


    private var contentView: some View {
        ZStack {
            spaceBackground

            if let lesson = selectedLesson {
                VStack(spacing: 22) {
                    Image(systemName: lesson.icon)
                        .font(.system(size: 78))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.blue.opacity(0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text(lesson.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Begin your mission.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 46))
                        .foregroundStyle(.white.opacity(0.8))

                    Text("Select a Lesson")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text("Choose a mission from the sidebar.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }


    private var spaceBackground: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.03, green: 0.05, blue: 0.12),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.55),
                    .clear,
                    Color.black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }
}


struct LessonRow: View {
    let lesson: Lesson
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {

            Image(systemName: lesson.icon)
                .foregroundStyle(isSelected ? Color.blue.opacity(0.9) : .white.opacity(0.8))

            Text(lesson.title)
                .font(.headline)
                .foregroundStyle(.white.opacity(isSelected ? 1.0 : 0.85))

            Spacer()

            if isSelected {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color.blue.opacity(0.8))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isSelected
                    ? LinearGradient(
                        colors: [
                            Color.black.opacity(0.85),
                            Color.blue.opacity(0.25)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(
                        colors: [
                            Color.white.opacity(0.04),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSelected
                    ? Color.blue.opacity(0.35)
                    : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        }
        .shadow(
            color: isSelected ? Color.blue.opacity(0.25) : .clear,
            radius: 12,
            x: 0,
            y: 6
        )
    }
}

