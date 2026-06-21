//
//  CodeLine.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-20.
//

import Foundation

struct CodeLine: Identifiable, Equatable {
    let id = UUID()
    let depth: Int
    let text: String
    
    static func == (lhs: CodeLine, rhs: CodeLine) -> Bool {
        lhs.id == rhs.id
    }
}
