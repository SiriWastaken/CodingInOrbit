//
//  Components.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI
import UIKit

// Shared building blocks: buttons that squish and bounce, the night-sky background,
// panels, arrival animations, and progress indicators.

// MARK: - Tap feedback

@MainActor
enum Feedback {
    private static var hapticsOn: Bool {
        UserDefaults.standard.object(forKey: "isHapticsEnabled") as? Bool ?? true
    }

    /// A soft tap for presses. Every button in the app calls this.
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) {
        guard hapticsOn else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: 0.8)
    }

    /// A tick for picking something, like a line of code or a menu choice.
    static func select() {
        guard hapticsOn else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Buttons

/// Squishes on press and springs back with a little bounce, with a light haptic tap.
struct BouncyButtonStyle: ButtonStyle {
    enum Kind {
        /// The one thing to do next. Filled nebula purple with the soft shadow.
        case primary
        /// Everything else. Transparent with a hairline edge.
        case secondary
        /// Run. Soft teal, the only filled element in the command bar.
        case run
    }

    var kind: Kind = .secondary
    /// Smaller text, for buttons tucked inside panels. Still a 44pt tap target.
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        BouncyButtonBody(configuration: configuration, kind: kind, compact: compact)
    }
}

private struct BouncyButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: BouncyButtonStyle.Kind
    let compact: Bool
    @Environment(\.isEnabled) private var isEnabled

    private var height: CGFloat {
        if compact || kind == .run { return Tap.minimum }
        return kind == .primary ? 56 : 48
    }

    private var radius: CGFloat {
        switch kind {
        case .primary: compact ? Radius.medium : Radius.large
        case .secondary: Radius.medium
        case .run: Radius.small
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            .font(compact ? Typeface.caption : Typeface.button)
            .foregroundStyle(ink)
            .padding(.horizontal, compact ? Space.m : Space.xl)
            .frame(minHeight: height)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(Color.starlight.opacity(kind == .secondary ? 0.2 : 0), lineWidth: 1))
            .shadow(color: .black.opacity(kind == .primary && !compact ? 0.3 : 0), radius: 12, y: 6)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(shape)
            .pressable(configuration.isPressed, scale: kind == .secondary ? 0.97 : 0.96)
    }

    private var fill: Color {
        switch kind {
        case .primary: .nebulaPurple
        case .secondary: .clear
        case .run: .softTeal
        }
    }

    private var ink: Color {
        switch kind {
        case .primary: .starlight
        case .secondary: .starlight.opacity(0.7)
        // Starlight on teal is too low-contrast to read, so Run uses the sky's color.
        case .run: .deepSpace
        }
    }
}

/// The squish and haptic without any chrome, for buttons that draw their own look
/// (mission cards, the Guiding Light's orb, icons).
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.93

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .pressable(configuration.isPressed, scale: scale)
    }
}

private struct Pressable: ViewModifier {
    let isPressed: Bool
    let scale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? scale : 1)
            .brightness(isPressed ? 0.06 : 0)
            .animation(Motion.press, value: isPressed)
            .onChange(of: isPressed) { _, pressed in
                if pressed { Feedback.tap(.light) }
            }
    }
}

extension View {
    func pressable(_ isPressed: Bool, scale: CGFloat = 0.93) -> some View {
        modifier(Pressable(isPressed: isPressed, scale: scale))
    }
}

/// A bare icon button for toolbars, like the back chevron. Always a 44pt tap target.
struct IconButtonLabel: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(Typeface.title)
            .foregroundStyle(Color.starlight)
            .frame(width: Tap.minimum, height: Tap.minimum)
    }
}

// MARK: - Background

/// The sky: flat deep space (or the splash artwork) with a few slow-twinkling stars.
/// No gradients, no grain. The stars do the work.
struct CozyBackground: View {
    var starCount = 15
    /// Shows the splash artwork instead of flat deep space.
    var showsSplash = false
    /// A black veil over the splash, so busy art doesn't fight what's on top.
    var dim: Double = 0

    var body: some View {
        ZStack {
            Color.deepSpace
            if showsSplash {
                // Color.clear takes the screen's size, so the filled image can't stretch the layout.
                Color.clear
                    .overlay {
                        Image("SplashScreen")
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                Color.black.opacity(dim)
            }
            StarfieldView(count: starCount)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Small stars in fixed places, each breathing between faint and dim on its own 3-5 second cycle.
struct StarfieldView: View {
    var count = 15
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Star {
        let x, y, size, period, phase: Double
    }

    private var stars: [Star] {
        var seed: UInt64 = 2027
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0..<count).map { _ in
            Star(x: next(), y: next(), size: 1 + next(), period: 3 + next() * 2, phase: next() * .pi * 2)
        }
    }

    var body: some View {
        let stars = self.stars
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for star in stars {
                    let wave = 0.5 + 0.5 * sin(time * 2 * .pi / star.period + star.phase)
                    context.opacity = reduceMotion ? 0.3 : 0.1 + 0.3 * wave
                    let rect = CGRect(x: star.x * size.width, y: star.y * size.height, width: star.size, height: star.size)
                    context.fill(Circle().path(in: rect), with: .color(.starlight))
                }
            }
        }
    }
}

// MARK: - Panels and arrival

extension View {
    /// A card: midnight blue, a hairline edge, and the one soft shadow.
    func cozyPanel(cornerRadius: CGFloat = Radius.large) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.midnightBlue)
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Color.starlight.opacity(0.1), lineWidth: 1))
                .softShadow()
        )
    }

    /// Fades and slides in on appear, with a little overshoot. Use `delay` to stagger panels.
    func arrive(delay: Double = 0, from offset: CGFloat = Space.xl) -> some View {
        modifier(Arrive(delay: delay, offset: offset))
    }
}

private struct Arrive: ViewModifier {
    let delay: Double
    let offset: CGFloat
    @State private var isShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .offset(y: isShown || reduceMotion ? 0 : offset)
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.arrive.delay(delay)) {
                    isShown = true
                }
            }
    }
}

// MARK: - Progress

/// Shows how far through its code the rocket is: a thin orbit line with a spark at the front.
struct OrbitProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width * max(0, min(1, progress))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.starlight.opacity(0.1))
                Capsule().fill(Color.goldTrim.opacity(0.85)).frame(width: width)
                SparkleShape()
                    .fill(Color.starlight)
                    .frame(width: Space.m, height: Space.m)
                    .shadow(color: Color.goldTrim, radius: Space.xs)
                    .offset(x: width - Space.m / 2)
            }
        }
        .frame(height: Space.xs)
        .animation(.easeOut(duration: 0.3), value: progress)
        .accessibilityElement()
        .accessibilityLabel("Run progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}
