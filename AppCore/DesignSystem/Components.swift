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

/// Squishes on press and springs back with a little bounce. Every button press also gives a soft haptic tap.
struct BouncyButtonStyle: ButtonStyle {
    enum Kind {
        /// The one thing to do next. Lamplight gold.
        case primary
        /// Everything else. A quiet panel with a brass edge.
        case secondary
        /// Stop, or anything that ends something. Ember.
        case ember
    }

    var kind: Kind = .secondary
    /// Smaller text and padding, for buttons tucked inside panels.
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

    private var fill: Color {
        switch kind {
        case .primary: .goldTrim
        case .secondary: .dusk
        case .ember: .ember
        }
    }

    private var ink: Color {
        kind == .secondary ? .starlight : .deepSpace
    }

    var body: some View {
        configuration.label
            .font(compact ? Typeface.caption : Typeface.button)
            .foregroundStyle(ink)
            .padding(.horizontal, compact ? Space.m : Space.l)
            .padding(.vertical, compact ? Space.xs + 2 : Space.s)
            .background(fill, in: Capsule())
            .overlay(Capsule().strokeBorder(kind == .secondary ? Color.goldTrim.opacity(0.35) : Color.starlight.opacity(0.25), lineWidth: 1))
            .shadow(color: (kind == .secondary ? Color.deepSpace : fill).opacity(0.45), radius: configuration.isPressed ? 2 : 8, y: configuration.isPressed ? 1 : 4)
            .opacity(isEnabled ? 1 : 0.45)
            .pressable(configuration.isPressed)
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
                if pressed { Feedback.tap() }
            }
    }
}

extension View {
    func pressable(_ isPressed: Bool, scale: CGFloat = 0.93) -> some View {
        modifier(Pressable(isPressed: isPressed, scale: scale))
    }
}

/// A round icon button for toolbars.
struct IconButtonLabel: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(Typeface.button)
            .foregroundStyle(Color.starlight)
            .frame(width: Space.xxl + Space.s, height: Space.xxl + Space.s)
            .background(Color.dusk, in: Circle())
            .overlay(Circle().strokeBorder(Color.goldTrim.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Background

/// The observatory sky: warm indigo, a lamp glow from below, a faint nebula,
/// twinkling stars, and a fine grain so it feels printed rather than flat.
struct CozyBackground: View {
    var starCount = 70
    /// Lays the splash artwork faintly into the sky.
    var splashOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.deepSpace
            if splashOpacity > 0 {
                // Color.clear takes the screen's size, so the filled image can't stretch the layout.
                Color.clear
                    .overlay {
                        Image("SplashScreen")
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .opacity(splashOpacity)
                    .blendMode(.screen)
            }
            RadialGradient(colors: [Color.goldTrim.opacity(0.13), .clear], center: .bottom, startRadius: 0, endRadius: 520)
            RadialGradient(colors: [Color.nebulaBlue.opacity(0.12), .clear], center: .topTrailing, startRadius: 0, endRadius: 480)
            StarfieldView(count: starCount)
            NoiseOverlay()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Stars in fixed places, each twinkling at its own pace. A few are warm gold.
struct StarfieldView: View {
    var count = 70
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Star {
        let x, y, size, speed, phase: Double
        let isGold: Bool
    }

    private var stars: [Star] {
        var seed: UInt64 = 2027
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0..<count).map { _ in
            Star(x: next(), y: next(), size: 1 + next() * 2.2, speed: 0.4 + next() * 1.4, phase: next() * .pi * 2, isGold: next() < 0.18)
        }
    }

    var body: some View {
        let stars = self.stars
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for star in stars {
                    let twinkle = reduceMotion ? 0.7 : 0.45 + 0.55 * (0.5 + 0.5 * sin(time * star.speed + star.phase))
                    let rect = CGRect(x: star.x * size.width, y: star.y * size.height, width: star.size, height: star.size)
                    context.opacity = twinkle
                    context.fill(Circle().path(in: rect), with: .color(star.isGold ? .goldTrim : .starlight))
                }
            }
        }
    }
}

/// A fine film-grain texture, generated once in code.
struct NoiseOverlay: View {
    private static let grain: UIImage = {
        let size = CGSize(width: 96, height: 96)
        var seed: UInt32 = 7
        return UIGraphicsImageRenderer(size: size).image { context in
            for x in 0..<96 {
                for y in 0..<96 {
                    seed = seed &* 1_664_525 &+ 1_013_904_223
                    let value = CGFloat(seed >> 24) / 255
                    Palette.starlight.withAlphaComponent(value * 0.5).setFill()
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }()

    var body: some View {
        Image(uiImage: Self.grain)
            .resizable(resizingMode: .tile)
            .opacity(0.05)
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }
}

// MARK: - Panels and arrival

extension View {
    /// A raised surface in the observatory: dusk, a hairline edge, and a soft shadow.
    func cozyPanel(cornerRadius: CGFloat = Radius.large) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.dusk.opacity(0.78))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Color.starlight.opacity(0.08), lineWidth: 1))
                .shadow(color: Color.deepSpace.opacity(0.6), radius: Space.m, y: Space.s)
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

/// Screen-to-screen: the old screen fades out and the new one rises in.
extension AnyTransition {
    static var drift: AnyTransition {
        .asymmetric(insertion: .opacity.combined(with: .offset(y: Space.xl)), removal: .opacity)
    }
}

// MARK: - Progress

/// Mission progress as a little constellation: each finished mission lights a star.
struct ConstellationProgress: View {
    let total: Int
    let completed: Int
    var starSize: CGFloat = Space.l

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<total, id: \.self) { index in
                let lit = index < completed
                SparkleShape()
                    .fill(lit ? Color.goldTrim : Color.starlight.opacity(0.18))
                    .frame(width: starSize, height: starSize)
                    .shadow(color: lit ? Color.goldTrim.opacity(0.8) : .clear, radius: Space.xs)
                    .rotationEffect(.degrees(Double(index) * 9 - 6))
                if index < total - 1 {
                    Rectangle()
                        .fill(Color.starlight.opacity(index < completed - 1 ? 0.5 : 0.12))
                        .frame(width: Space.m, height: 1)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(completed) of \(total) missions complete")
    }
}

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

// MARK: - Zoom navigation

extension View {
    /// Marks a view (like a mission card) as the place a screen zooms out of. iOS 18 and later.
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Zooms a pushed screen out of its source. On iOS 17 the screen's own arrival animation does the work.
    @ViewBuilder
    func zoomTransition(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
