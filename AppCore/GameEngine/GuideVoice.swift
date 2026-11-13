//
//  GuideVoice.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import Foundation

// Everything the Guiding Light says that isn't tied to one mission lives here.
// Voice: a warm, curious companion who is discovering this universe at the same time as you.
// It never lectures and never claims to know what a line will do. It wonders, it's surprised,
// and it's delighted when something appears. Contractions, questions, never more than 2-3 sentences.

/// How the Guiding Light is feeling. Its orb changes color to match.
enum GuideMood: Equatable {
    case calm, curious, delighted, concerned
}

enum GuideVoice {
    static let running = [
        "3... 2... 1... go!",
        "Engines humming. Watch the glowing line!",
        "Here we go. I can't look. Okay, I'm looking."
    ]

    /// Free play: the Guiding Light mostly stays quiet.
    static let whispers = ["Whoa.", "Gorgeous.", "Do another!", "I love that.", "Ooh."]

    static let finale = "You've done it, Commander. The world is yours. Build something great."
    static let emptyCode = "The sky's empty! Tap a block below and let's fill it."
    static let editorPlaceholder = "Type a command…"
    static let allBlocksUsed = "You've used every block! You're officially dangerous."
    static let tenthCommand = "10 commands! The Apollo computer had less memory than a calculator, and it still got to the Moon."
    static let freshStart = "Clean slate. Every universe starts empty."
    static let firstMistake = "Ooh, a bug! The very first computer bug was a real moth, stuck inside a computer in 1947."
    static let nothingLeftToTry = "It's all here! Want to go wild and add something extra?"

    // MARK: Reactions to new things

    /// Said the first time each kind of thing appears: one real fact from space, fast.
    static func reaction(to body: Body) -> String {
        switch body.thing {
        case .launchpad: "A launchpad! Real ones spray a flood of water during liftoff, just to soak up the noise."
        case .rocket: "A rocket! The Saturn V burned 20 tons of fuel every second. Ours runs on words."
        case .star: "A star! You could fit 1.3 million Earths inside our Sun."
        case .planet: "A whole planet, from one line! A day on Venus is longer than its year. True story."
        case .moon: "A moon! Ours drifts about 4 cm farther from Earth every year. Wave while you can."
        case .satellite: "A satellite! The space station laps Earth every 90 minutes. That's 16 sunrises a day."
        case .asteroid: "An asteroid! Some are solid metal. Floating treasure."
        case .comet: "A comet! Its tail always points away from the Sun, even when it's leaving. Make a wish!"
        case .rover: "A rover! Curiosity once hummed Happy Birthday to itself on Mars. Ours has us."
        case .base: "A base! Apollo astronauts said moon dust smells like burnt gunpowder. Keep the door shut."
        }
    }

    static let liftoff = "Nice one! We have liftoff."
    static let askName = "Before we fly: what should we call your rocket?"
    static let freePlayHelp = "Try create planet, then repeat 3 times: create satellite. Or anything else!"
    static let orbiting = "We're orbiting! Fun fact: an orbit is just falling... and missing the ground, forever."
    static let orbitMadeAPlanet = "Wait, there wasn't a planet, so orbit made one? Of course it did. You can't circle nothing!"
    static let exploring = "You made it. Touchdown."

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
