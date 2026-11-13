//
//  Theme.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI
import UIKit

// The design system: a cozy observatory at night, not a control room.
// Every color, font, gap, corner, and shadow in the app comes from this file.
// If something on screen looks off, the fix belongs here, not in a one-off literal.

// MARK: - Palette

/// Six colors, and only six. Each one has a single job.
enum Palette {
    /// Backgrounds. The night sky behind everything.
    static let deepSpace = UIColor(red: 0.039, green: 0.055, blue: 0.102, alpha: 1)   // #0A0E1A
    /// Backgrounds. Panels, cards, the workspace.
    static let midnightBlue = UIColor(red: 0.078, green: 0.106, blue: 0.180, alpha: 1) // #141B2E
    /// Text, always. Dim it with opacity, never with another color.
    static let starlight = UIColor(red: 0.961, green: 0.941, blue: 0.882, alpha: 1)    // #F5F0E1
    /// Accent: the Guiding Light, celebration, and gentle warnings.
    static let goldTrim = UIColor(red: 0.831, green: 0.686, blue: 0.216, alpha: 1)     // #D4AF37
    /// Accent: anything you can press to move forward.
    static let nebulaPurple = UIColor(red: 0.424, green: 0.169, blue: 0.851, alpha: 1) // #6C2BD9
    /// Success, and Run.
    static let softTeal = UIColor(red: 0.290, green: 0.608, blue: 0.557, alpha: 1)     // #4A9B8E
}

extension Color {
    static let deepSpace = Color(uiColor: Palette.deepSpace)
    static let midnightBlue = Color(uiColor: Palette.midnightBlue)
    static let starlight = Color(uiColor: Palette.starlight)
    static let goldTrim = Color(uiColor: Palette.goldTrim)
    static let nebulaPurple = Color(uiColor: Palette.nebulaPurple)
    static let softTeal = Color(uiColor: Palette.softTeal)
}

extension UIColor {
    /// Blends toward another palette color, so new shades never need new literals.
    func mixed(with other: UIColor, _ amount: CGFloat) -> UIColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = max(0, min(1, amount))
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }
}

// MARK: - Typography

/// Two families: New York (the system serif) for headings, SF Pro for reading, plus SF Mono
/// for code. Six sizes, each scaled with Dynamic Type from its base point size.
enum Typeface {
    private static var prefersEasyReading: Bool {
        UserDefaults.standard.bool(forKey: "isDyslexicFont")
    }

    private static func scaled(_ size: CGFloat, like style: UIFont.TextStyle) -> CGFloat {
        UIFontMetrics(forTextStyle: style).scaledValue(for: size)
    }

    /// Serif normally. Rounded (or OpenDyslexic, if bundled) when the dyslexia-friendly option is on.
    private static func heading(_ size: CGFloat, _ weight: Font.Weight, like style: UIFont.TextStyle) -> Font {
        let points = scaled(size, like: style)
        guard prefersEasyReading else { return .system(size: points, weight: weight, design: .serif) }
        if UIFont(name: "OpenDyslexic", size: points) != nil { return .custom("OpenDyslexic", fixedSize: points) }
        return .system(size: points, weight: weight, design: .rounded)
    }

    private static func reading(_ size: CGFloat, _ weight: Font.Weight, like style: UIFont.TextStyle) -> Font {
        let points = scaled(size, like: style)
        guard prefersEasyReading else { return .system(size: points, weight: weight) }
        if UIFont(name: "OpenDyslexic", size: points) != nil { return .custom("OpenDyslexic", fixedSize: points) }
        return .system(size: points, weight: weight, design: .rounded)
    }

    static var hero: Font { heading(56, .bold, like: .largeTitle) }
    static var largeTitle: Font { heading(34, .bold, like: .largeTitle) }
    static var title: Font { heading(24, .semibold, like: .title2) }
    static var body: Font { reading(17, .regular, like: .body) }
    /// The body size, a little heavier, for button labels.
    static var button: Font { reading(17, .medium, like: .body) }
    static var caption: Font { reading(13, .regular, like: .caption1) }
    static var code: Font { .system(size: scaled(16, like: .body), design: .monospaced) }
}

// MARK: - Spacing

/// Every gap in the app is one of these six.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// Three corners: small for code and chips, medium for bars and secondary buttons, large for cards.
enum Radius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}

/// The minimum size of anything you can tap.
enum Tap {
    static let minimum: CGFloat = 44
}

extension View {
    /// The one shadow in the app.
    func softShadow() -> some View {
        shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
}

// MARK: - Motion

enum Motion {
    /// A press: quick and soft.
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.6)
    /// Panels and cards arriving: a little overshoot, like setting a book down a bit too eagerly.
    static let arrive = Animation.spring(response: 0.55, dampingFraction: 0.68)
    /// Toggles flipping.
    static let toggle = Animation.spring(response: 0.3, dampingFraction: 0.7)
    /// Slow, breathing loops for glows and floating.
    static let breathe = Animation.easeInOut(duration: 2.4)
}
