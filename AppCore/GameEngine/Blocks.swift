//
//  Blocks.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-19.
//

import Foundation
import SwiftUI

// The purpose of this file is to manage the availible blocks displayed in the lesson view and GlobalGameView. These blocks each have a unique id, as well as tite, icon, command, and category. This is in its own seperate file and is not being created and parsed with the renderer to make modifications easier. If I want to add more blocks with lessons in the future, that's going to be much easier because of this file.

struct Block: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let command: String
    let category: String
    
}

let blocksArray : [Block] = [
    Block(title: "Launch", icon: "rocket", command: "launch", category: "Movement"),
    Block(title: "Move", icon: "arrow.up", command: "move", category: "Movement"),
    Block(title: "Repeat", icon: "arrow.triangle.2.circlepath", command: "repeat", category: "Loop"),
    Block(title: "If", icon: "questionmark.circle", command: "if", category: "Condition")
]
