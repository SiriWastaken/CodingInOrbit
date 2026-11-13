//
//  Theme.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI
import UIKit

// The look of Coding In Orbit: a cozy observatory at night, not a control room.
// Every color, font, and gap in the app comes from this file. If something on screen
// looks off, the fix belongs here, not in a one-off literal.

// MARK: - Palette

/// Six colors, and only six. Lighter or darker versions come from mixing these together.
enum Palette {
    /// The night sky behind everything. A warm, inky indigo instead of pure black.
    static let deepSpace = UIColor(red: 0.09, green: 0.08, blue: 0.17, alpha: 1)
    /// Raised surfaces: panels, cards, the editor. Like the wooden walls of an observatory at dusk.
    static let dusk = UIColor(red: 0.17, green: 0.15, blue: 0.28, alpha: 1)
    /// Text and the brightest stars. Warm, like candlelight on paper.
    static let starlight = UIColor(red: 0.97, green: 0.93, blue: 0.86, alpha: 1)
    /// The Guiding Light, success, and the Run button. Brass and lamplight.
    static let goldTrim = UIColor(red: 0.96, green: 0.75, blue: 0.38, alpha: 1)
    /// Calm and curious: the rocket's trail, the "all clear" sensor, commands in code.
    static let nebulaBlue = UIColor(red: 0.56, green: 0.65, blue: 0.96, alpha: 1)
    /// Warmth and warnings: the rocket's paint, asteroids ahead, gentle errors.
    static let ember = UIColor(red: 0.93, green: 0.50, blue: 0.41, alpha: 1)
}

extension Color {
    static let deepSpace = Color(uiColor: Palette.deepSpace)
    static let dusk = Color(uiColor: Palette.dusk)
    static let starlight = Color(uiColor: Palette.starlight)
    static let goldTrim = Color(uiColor: Palette.goldTrim)
    static let nebulaBlue = Color(uiColor: Palette.nebulaBlue)
    static let ember = Color(uiColor: Palette.ember)
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

/// Two typefaces. New York (the system serif) is the storyteller: titles and the
/// Guiding Light's voice. SF Mono is the engineer: code, labels, and small print.
/// Every size follows Dynamic Type.
enum Typeface {
    private static var prefersEasyReading: Bool {
        UserDefaults.standard.bool(forKey: "isDyslexicFont")
    }

    /// Serif normally. Rounded when the dyslexia-friendly option is on (or OpenDyslexic, if bundled).
    private static func story(_ style: Font.TextStyle) -> Font {
        guard prefersEasyReading else { return .system(style, design: .serif) }
        if UIFont(name: "OpenDyslexic", size: 17) != nil {
            return .custom("OpenDyslexic", size: UIFont.preferredFont(forTextStyle: style.uiKit).pointSize, relativeTo: style)
        }
        return .system(style, design: .rounded)
    }

    static var largeTitle: Font { story(.largeTitle).weight(.bold) }
    static var title: Font { story(.title2).weight(.semibold) }
    static var body: Font { story(.body) }
    static var button: Font { story(.body).weight(.semibold) }
    static var caption: Font { .system(.caption, design: .monospaced).weight(.medium) }
    static var code: Font { .system(.body, design: .monospaced) }
}

private extension Font.TextStyle {
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}

// MARK: - Spacing

/// Every gap in the app is one of these.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let card: CGFloat = 24
}

// MARK: - Motion

enum Motion {
    /// A press: quick and soft.
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.6)
    /// Panels and cards arriving: a little overshoot, like setting a book down a bit too eagerly.
    static let arrive = Animation.spring(response: 0.55, dampingFraction: 0.68)
    /// Slow, breathing loops for glows and floating.
    static let breathe = Animation.easeInOut(duration: 2.4)
}
