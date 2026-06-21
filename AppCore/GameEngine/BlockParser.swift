//
//  BlockParser.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-20.
//

import Foundation

enum Command {
    case launch
    case move(direction: Direction)
    case unknown(String)
}

enum Direction {
    case up
    case down
    case left
    case right
}

struct BlockParser {
    static func parse(_ line: CodeLine) -> Command {
        let trimmed = line.text.trimmingCharacters(in: .whitespaces)
        
        switch trimmed {
        case "launch()":
            return .launch
        case "move(up)":
            return .move(direction: .up)
        case "move(down)":
            return .move(direction: .down)
        case "move(left)":
            return .move(direction: .left)
        case "move(right)":
            return .move(direction: .right)
        default:
            return .unknown(trimmed)
        }
    }
    
    static func parseCode(_ text: String) -> [CodeLine] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var result: [CodeLine] = []
        
        for line in lines {
            let lineString = String(line)
            let leadingSpaces = lineString.prefix(while: { $0 == " " || $0 == "\t" }).count
            let depth = leadingSpaces / 4
            let trimmed = lineString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result.append(CodeLine(depth: depth, text: trimmed))
            }
        }
        return result
    }
    
    static func execute(_ codeLines: [CodeLine], on rocket: inout Rocket) -> [String] {
        var logs: [String] = []
        
        for line in codeLines {
            let command = parse(line)
            
            switch command {
            case .launch:
                rocket.launch()
                logs.append("✅ Launch successful")
                
            case .move(let direction):
                switch direction {
                case .up:
                    rocket.moveUp()
                    logs.append("⬆️ Moved up")
                case .down:
                    rocket.moveDown()
                    logs.append("⬇️ Moved down")
                case .left:
                    rocket.moveLeft()
                    logs.append("⬅️ Moved left")
                case .right:
                    rocket.moveRight()
                    logs.append("➡️ Moved right")
                }
                
            case .unknown(let command):
                logs.append("❌ Unknown command: \(command)")
            }
        }
        return logs
    }
}
