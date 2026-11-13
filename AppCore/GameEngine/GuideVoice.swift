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
        "Here we go! I have no idea what's about to appear. Watch the glowing line.",
        "Ooh, ooh. Let's see what your words make out here.",
        "Fingers crossed! Keep an eye on the highlighted line."
    ]

    static let emptyCode = "Nothing to run yet! Try tapping a block below, or type create(launchpad). I'm curious what happens."
    static let editorPlaceholder = "Type a command. Words make things here."
    static let allBlocksUsed = "Look at you go! You've used every block I gave you."
    static let tenthCommand = "That's your 10th command! Look how much exists now that didn't before."
    static let freshStart = "Fresh start! A blank page is the bravest place to begin."
    static let firstMistake = "Hmm, that didn't work. Neither of us knew it wouldn't, though. That's how we find things out."
    static let nothingLeftToTry = "I think everything we were looking for is already here! Want to see what else we can make?"

    // MARK: Reactions to new things

    /// Said the first time each kind of thing appears. The Guiding Light is just as surprised as you.
    static func reaction(to body: Body) -> String {
        switch body.thing {
        case .launchpad: "A launchpad! It just... appeared. I didn't know words could do that."
        case .rocket: "Oh, a rocket! It looks so happy to be here."
        case .star: "A star! I can feel the warmth from here. Isn't that something?"
        case .planet: "A whole planet. From one line! I'm a little dizzy."
        case .moon: "A moon! Look at it, it knows exactly which way to circle."
        case .satellite: "Ooh, a satellite. It's blinking at us."
        case .asteroid: "An asteroid, just drifting by. I hope it's friendly."
        case .comet: "A comet! Quick, make a wish."
        case .rover: "A little rover! It's already looking around."
        case .base: "A base! Those windows look like they're waiting for someone to visit."
        }
    }

    static let liftoff = "Liftoff! I felt that one all the way through my glow."
    static let orbiting = "It's circling! Did you see how it found its way around?"
    static let orbitMadeAPlanet = "Wait, there wasn't a planet, so orbit() made one? Of course it did. You can't circle nothing!"
    static let exploring = "The rover found the base! I wonder what they're saying to each other."

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
