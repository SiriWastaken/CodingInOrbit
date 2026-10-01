//
//  GuideVoice.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import Foundation

// Everything the Guiding Light says that isn't tied to one mission lives here.
// Voice: a warm, wise, slightly playful mentor who loves space. Contractions, questions,
// small celebrations. Never more than 2–3 sentences, and never a lecture.

/// How the Guiding Light is feeling. Its orb changes color to match.
enum GuideMood: Equatable {
    case calm, curious, delighted, concerned
}

enum GuideVoice {
    static let running = [
        "Here we go! Follow the glowing line. That's the one running right now.",
        "Ooh, liftoff time. Watch each line light up as the rocket follows it.",
        "Fingers crossed! Keep an eye on the highlighted line."
    ]

    static let emptyCode = "Your code goes here. Be adventurous! Tap a block below, or type launch()."
    static let editorPlaceholder = "Your code goes here. Be adventurous."
    static let allBlocksUsed = "Look at you go! You've used every block I gave you."
    static let tenthCommand = "That's your 10th command! You know, every astronaut in history started with just one."
    static let freshStart = "Fresh start! Sometimes that's the bravest move of all."
    static let firstMistake = "Hmm, that didn't work. But mistakes are how we learn."

    static let crashes = [
        "Asteroids 1, Rocket 0! Tap the trail to see which line did it, then let's try again.",
        "Ouch! Tap the rocket's trail to find the line that steered us wrong.",
        "Bonk! Don't worry, the rocket's tougher than it looks. Which line sent it that way?"
    ]

    // MARK: Easter eggs

    static let hello = [
        "Well, hello to you too! It's lovely to have company out here.",
        "Hi there! You know, you're the first person to say hello to me in a few thousand years.",
        "Hello, hello! The stars say hi too. Well, they twinkle. Same thing."
    ]
    static let suitUp = "Astronaut mode: on! Helmet sealed, visor shining. Looking sharp, Commander."
    static let suitUpAgain = "You're already suited up! Any more layers and you'll float away."
    static let stargaze = "Look up! That's the Big Dipper. People have found their way home by it for thousands of years."

    static func pick(_ lines: [String]) -> String {
        lines.randomElement() ?? ""
    }
}
