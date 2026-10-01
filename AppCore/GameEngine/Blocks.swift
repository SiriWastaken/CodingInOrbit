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
    case launch, move, repeatLoop, condition
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

let blocksArray: [Block] = [
    Block(id: .launch, title: "Launch", icon: "flame.fill", category: "Movement", snippets: [
        Snippet(title: "Launch", icon: "flame.fill", code: "launch()")
    ]),
    Block(id: .move, title: "Move", icon: "arrow.up.and.down.and.arrow.left.and.right", category: "Movement", snippets: Direction.allCases.map {
        Snippet(title: "Move \($0.rawValue)", icon: "arrow.\($0.rawValue)", code: "move(\($0.rawValue))")
    }),
    Block(id: .repeatLoop, title: "Repeat", icon: "arrow.triangle.2.circlepath", category: "Loop", snippets: [
        Snippet(title: "Repeat 3 times", icon: "arrow.triangle.2.circlepath", code: "repeat 3 {\n    $0\n}")
    ]),
    Block(id: .condition, title: "If", icon: "questionmark.diamond", category: "Condition", snippets: [
        Snippet(title: "If asteroid ahead", icon: "questionmark.diamond", code: "if asteroidAhead {\n    $0\n}"),
        Snippet(title: "If… else", icon: "arrow.triangle.branch", code: "if asteroidAhead {\n    $0\n} else {\n    \n}")
    ])
]

func blocks(for kinds: [BlockKind]) -> [Block] {
    blocksArray.filter { kinds.contains($0.id) }
}
