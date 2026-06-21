//
//  Rocket.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-20.
//

import Foundation
import SwiftUI

struct Rocket {
    var row: Int = 10
    var col: Int = 10
    var fuel: Int = 100
    var isLaunched: Bool = false
    var stability: Double = 1.0
    
    mutating func launch() {
        isLaunched = true
    }
    
    mutating func moveUp() {
        if row > 0 { row -= 1 }
    }
    
    mutating func moveDown() {
        if row < 19 { row += 1 }
    }
    
    mutating func moveLeft() {
        if col > 0 { col -= 1 }
    }
    
    mutating func moveRight() {
        if col < 19 { col += 1 }
    }
}

struct RocketView: View {
    let rocket: Rocket
    
    var body: some View {
        // TO-DO BEFORE SUBMISSION: Replace with an image of a drawn rocket by me... It adds a personal touch..
        Image(systemName: "paperplane.fill")
            .font(.title)
            .foregroundColor(.blue)
            .rotationEffect(.degrees(rocket.isLaunched ? 45 : 0))
    }
}
