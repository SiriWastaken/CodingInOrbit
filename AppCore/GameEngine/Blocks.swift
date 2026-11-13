//
//  Blocks.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-19.
//

import Foundation
import SwiftUI

// The purpose of this file is to manage the availible blocks displayed in the lesson view and GlobalGameView. These blocks each have a unique id, as well as tite, icon, command, and category. This is in its own seperate file and is not being created and parsed with the renderer to make modifications easier. If I want to add more blocks with lessons in the future, that's going to be much easier because of this file.
//
// Each block holds one or more snippets of code. A block with several snippets (like Move)
// shows a menu. "$0" marks where the cursor lands after the snippet is inserted.

enum BlockKind: String, Sendable {
    case create, build, spawn, summon
    case launch, orbit, explore, move
    case repeatLoop, condition

    /// The verb a creation block writes, if it is one.
    var verb: Verb? { Verb(rawValue: rawValue) }
}

struct Snippet: Identifiable, Sendable {
    var id: String { code }
    let title: String
    let icon: String
    let code: String
}

struct Block: Identifiable, Sendable {
    let id: BlockKind
    let title: String
    let icon: String
    let category: String
    let snippets: [Snippet]
}

/// The blocks a mission offers. Creation blocks list the things that can exist on its stage.
func blocks(for kinds: [BlockKind], stage: Stage) -> [Block] {
    kinds.map { kind in
        switch kind {
        case .create, .build, .spawn, .summon:
            let verb = kind.verb ?? .create
            let icon = switch verb {
            case .create: "sparkles"
            case .build: "hammer.fill"
            case .spawn: "plus.circle.fill"
            case .summon: "wand.and.stars"
            }
            return Block(id: kind, title: verb.rawValue.capitalized, icon: icon, category: "Creation",
                         snippets: stage.allowed.map { Snippet(title: "\(verb.rawValue.capitalized) \($0.rawValue)", icon: $0.icon, code: "\(verb.rawValue)(\($0.rawValue))") })
        case .launch:
            return single(kind, "Launch", "flame.fill", "launch()")
        case .orbit:
            return single(kind, "Orbit", "arrow.triangle.2.circlepath", "orbit()")
        case .explore:
            return single(kind, "Explore", "binoculars.fill", "explore()")
        case .move:
            return Block(id: kind, title: "Move", icon: "arrow.up.and.down.and.arrow.left.and.right", category: "Movement",
                         snippets: Direction.allCases.map { Snippet(title: "Move \($0.rawValue)", icon: "arrow.\($0.rawValue)", code: "move(\($0.rawValue))") })
        case .repeatLoop:
            return Block(id: kind, title: "Repeat", icon: "arrow.triangle.2.circlepath", category: "Loop", snippets: [
                Snippet(title: "Repeat 3 times", icon: "arrow.triangle.2.circlepath", code: "repeat 3 {\n    $0\n}")
            ])
        case .condition:
            let subject = switch stage {
            case .launchSite: Thing.rocket.rawValue
            case .orbit: Thing.planet.rawValue
            case .moon: Thing.moon.rawValue
            }
            return Block(id: kind, title: "If", icon: "questionmark.diamond", category: "Condition", snippets: [
                Snippet(title: "If \(subject) exists", icon: "questionmark.diamond", code: "if \(subject) {\n    $0\n}"),
                Snippet(title: "If there's no \(subject)", icon: "nosign", code: "if not \(subject) {\n    $0\n}"),
                Snippet(title: "If… else", icon: "arrow.triangle.branch", code: "if \(subject) {\n    $0\n} else {\n    \n}")
            ])
        }
    }
}

private func single(_ kind: BlockKind, _ title: String, _ icon: String, _ code: String) -> Block {
    Block(id: kind, title: title, icon: icon, category: "Action", snippets: [Snippet(title: title, icon: icon, code: code)])
}
