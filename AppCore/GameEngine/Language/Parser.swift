//
//  Parser.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import Foundation

// Turning code into something the rocket understands happens in two steps:
// 1. The Lexer chops the text into tokens: words, numbers, and symbols like ( and {.
// 2. The Parser reads those tokens and builds a tree of Statements.
// Every error is written for a beginner: what went wrong, and how to fix it.

enum TokenKind: Equatable {
    case identifier(String)
    case number(Int)
    case leftParen, rightParen, leftBrace, rightBrace, comma
    case newline
    case symbol(Character)
    case end

    /// How the token looks in code, for error messages.
    var display: String {
        switch self {
        case .identifier(let word): "\"\(word)\""
        case .number(let value): "\(value)"
        case .leftParen: "("
        case .rightParen: ")"
        case .leftBrace: "{"
        case .rightBrace: "}"
        case .comma: ","
        case .newline: "the end of the line"
        case .symbol(let character): "\"\(character)\""
        case .end: "the end of your code"
        }
    }
}

struct Token: Equatable {
    let kind: TokenKind
    let line: Int
}

enum Lexer {
    static func tokenize(_ source: String) -> [Token] {
        var tokens: [Token] = []
        let characters = Array(source)
        var line = 1
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character == "\n" || character == ";" {
                tokens.append(Token(kind: .newline, line: line))
                if character == "\n" { line += 1 }
                index += 1
            } else if character.isWhitespace {
                index += 1
            } else if character == "/", index + 1 < characters.count, characters[index + 1] == "/" {
                // A comment: skip to the end of the line.
                while index < characters.count, characters[index] != "\n" { index += 1 }
            } else if character.isLetter || character == "_" {
                var word = ""
                while index < characters.count, characters[index].isLetter || characters[index].isASCIINumber || characters[index] == "_" {
                    word.append(characters[index])
                    index += 1
                }
                tokens.append(Token(kind: .identifier(word), line: line))
            } else if character.isASCIINumber {
                var digits = ""
                while index < characters.count, characters[index].isASCIINumber {
                    digits.append(characters[index])
                    index += 1
                }
                tokens.append(Token(kind: .number(Int(digits) ?? Int.max), line: line))
            } else {
                let kind: TokenKind = switch character {
                case "(": .leftParen
                case ")": .rightParen
                case "{": .leftBrace
                case "}": .rightBrace
                case ",": .comma
                default: .symbol(character)
                }
                tokens.append(Token(kind: kind, line: line))
                index += 1
            }
        }

        tokens.append(Token(kind: .end, line: line))
        return tokens
    }
}

private extension Character {
    var isASCIINumber: Bool { isASCII && isNumber }
}

struct Parser {
    static let commands = ["launch", "move", "repeat", "if", "else"]

    private let tokens: [Token]
    private var position = 0

    private init(tokens: [Token]) {
        self.tokens = tokens
    }

    static func parse(_ source: String) -> Result<[Statement], CodeError> {
        var parser = Parser(tokens: Lexer.tokenize(source))
        do {
            return .success(try parser.parseBlock(openedOnLine: nil))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Token helpers

    private var current: Token { tokens[position] }

    private mutating func advance() {
        if position < tokens.count - 1 { position += 1 }
    }

    private mutating func skipNewlines() {
        while current.kind == .newline { advance() }
    }

    /// Looks ahead past blank lines without moving, so `}` and `else` can sit on different lines.
    private func peekPastNewlines() -> Token {
        var index = position
        while tokens[index].kind == .newline { index += 1 }
        return tokens[index]
    }

    // MARK: - Blocks and statements

    /// Reads statements until the end of the code, or until the `}` that closes this block.
    private mutating func parseBlock(openedOnLine openLine: Int?) throws(CodeError) -> [Statement] {
        var statements: [Statement] = []
        while true {
            skipNewlines()
            switch current.kind {
            case .end:
                if let openLine {
                    throw CodeError(line: openLine, "The { on line \(openLine) never closes.",
                                    hint: "Every { needs a matching } after the code inside it.")
                }
                return statements
            case .rightBrace:
                guard openLine != nil else {
                    throw CodeError(line: current.line, "This } doesn't have a { to close.",
                                    hint: "Remove it, or check that your repeat or if has a {.")
                }
                advance()
                return statements
            default:
                statements.append(try parseStatement())
                try expectEndOfStatement()
            }
        }
    }

    private func expectEndOfStatement() throws(CodeError) {
        switch current.kind {
        case .newline, .rightBrace, .end:
            return
        default:
            throw CodeError(line: current.line, "Each command needs its own line.",
                            hint: "Press return before \(current.kind.display).")
        }
    }

    private mutating func parseStatement() throws(CodeError) -> Statement {
        let token = current
        guard case .identifier(let word) = token.kind else {
            throw unexpected(token)
        }
        switch word {
        case "launch":
            advance()
            try parseEmptyArguments(for: "launch", line: token.line)
            return .launch(line: token.line)
        case "move":
            advance()
            return .move(try parseDirectionArgument(line: token.line), line: token.line)
        case "repeat":
            advance()
            return try parseRepeat(line: token.line)
        case "if":
            advance()
            return try parseIf(line: token.line)
        case "else":
            throw CodeError(line: token.line, "This else isn't attached to an if.",
                            hint: "Put else right after an if block's }, like: } else {")
        default:
            throw unknownWord(word, line: token.line)
        }
    }

    private mutating func parseEmptyArguments(for name: String, line: Int) throws(CodeError) {
        guard current.kind == .leftParen else {
            throw CodeError(line: line, "\(name) needs parentheses.", hint: "Write it as \(name)().")
        }
        advance()
        guard current.kind == .rightParen else {
            throw CodeError(line: line, "\(name)() doesn't need anything inside the ( ).", hint: "Write it as \(name)().")
        }
        advance()
    }

    private mutating func parseDirectionArgument(line: Int) throws(CodeError) -> Direction {
        let choices = "Try move(up), move(down), move(left), or move(right)."
        guard current.kind == .leftParen else {
            if case .identifier(let word) = current.kind, let direction = Direction(rawValue: word.lowercased()) {
                throw CodeError(line: line, "move needs parentheses around the direction.",
                                hint: "Write it as move(\(direction.rawValue)).")
            }
            throw CodeError(line: line, "Which way should the rocket move?", hint: choices)
        }
        advance()

        guard case .identifier(let word) = current.kind else {
            throw CodeError(line: line, "Which way should the rocket move?", hint: choices)
        }
        guard let direction = Direction(rawValue: word) else {
            if let direction = Direction(rawValue: word.lowercased()) {
                throw CodeError(line: line, "Directions are written in lowercase.", hint: "Write it as move(\(direction.rawValue)).")
            }
            let suggestion = Suggestions.closest(to: word, in: Direction.allCases.map(\.rawValue))
            throw CodeError(line: line, "The rocket doesn't know the direction \"\(word)\".",
                            hint: suggestion.map { "Did you mean move(\($0))?" } ?? choices)
        }
        advance()

        guard current.kind == .rightParen else {
            throw CodeError(line: line, "move( is missing its closing ).", hint: "Write it as move(\(direction.rawValue)).")
        }
        advance()
        return direction
    }

    private mutating func parseRepeat(line: Int) throws(CodeError) -> Statement {
        // Both `repeat 3 {` and `repeat(3) {` are accepted.
        let hasParenthesis = current.kind == .leftParen
        if hasParenthesis { advance() }

        guard case .number(let count) = current.kind else {
            throw CodeError(line: line, "How many times should it repeat?", hint: "Put a number after repeat, like: repeat 3 {")
        }
        advance()

        if hasParenthesis {
            guard current.kind == .rightParen else {
                throw CodeError(line: line, "repeat(\(count) is missing its closing ).", hint: "Write it as: repeat 3 {")
            }
            advance()
        }

        guard current.kind == .leftBrace else {
            throw CodeError(line: line, "repeat \(count) needs a { to start its block.",
                            hint: "Write repeat \(count) {, then the commands to repeat, then }.")
        }
        advance()
        let body = try parseBlock(openedOnLine: line)
        return .repeatLoop(count: count, body: body, line: line)
    }

    private mutating func parseIf(line: Int) throws(CodeError) -> Statement {
        let hasParenthesis = current.kind == .leftParen
        if hasParenthesis { advance() }

        guard case .identifier(let word) = current.kind else {
            throw CodeError(line: line, "What should the rocket check?", hint: "Try: if asteroidAhead {")
        }
        guard let condition = Condition(rawValue: word) else {
            let suggestion = Suggestions.closest(to: word, in: Condition.allCases.map(\.rawValue))
            throw CodeError(line: line, "The rocket doesn't have a sensor called \"\(word)\".",
                            hint: suggestion.map { "Did you mean \($0)?" } ?? "Try: if asteroidAhead {")
        }
        advance()

        if hasParenthesis {
            guard current.kind == .rightParen else {
                throw CodeError(line: line, "if( is missing its closing ).", hint: "Write it as: if \(word) {")
            }
            advance()
        }

        guard current.kind == .leftBrace else {
            throw CodeError(line: line, "if \(word) needs a { to start its block.", hint: "Write it as: if \(word) {")
        }
        advance()
        let thenBody = try parseBlock(openedOnLine: line)

        var elseBody: [Statement]?
        if case .identifier("else") = peekPastNewlines().kind {
            skipNewlines()
            let elseLine = current.line
            advance()
            if case .identifier("if") = current.kind {
                let nestedLine = current.line
                advance()
                elseBody = [try parseIf(line: nestedLine)]
            } else {
                guard current.kind == .leftBrace else {
                    throw CodeError(line: elseLine, "else needs a { to start its block.", hint: "Write it as: } else {")
                }
                advance()
                elseBody = try parseBlock(openedOnLine: elseLine)
            }
        }
        return .ifElse(condition, then: thenBody, otherwise: elseBody, line: line)
    }

    // MARK: - Friendly errors

    private func unknownWord(_ word: String, line: Int) -> CodeError {
        let lowered = word.lowercased()

        if Self.commands.contains(lowered) {
            let example = lowered == "launch" ? "launch()" : lowered == "move" ? "move(up)" : lowered
            return CodeError(line: line, "Commands are written in lowercase.", hint: "Write it as \(example).")
        }
        if lowered == "rocket" {
            return CodeError(line: line, "You don't need to write \"\(word)\". The rocket knows you're talking to it.",
                             hint: "Just write the command, like move(up).")
        }
        if let direction = Direction(rawValue: lowered) {
            return CodeError(line: line, "\"\(word)\" is a direction, not a command.", hint: "Did you mean move(\(direction.rawValue))?")
        }
        if let direction = Direction.allCases.first(where: { lowered == "move" + $0.rawValue }) {
            return CodeError(line: line, "Almost! The direction goes inside the parentheses.", hint: "Write it as move(\(direction.rawValue)).")
        }
        if Condition(rawValue: word) != nil {
            return CodeError(line: line, "\(word) is a sensor. The rocket checks it with if.", hint: "Try: if \(word) {")
        }
        if ["for", "while", "func", "let", "var", "print", "return", "switch", "guard"].contains(word) {
            return CodeError(line: line, "\"\(word)\" is real Swift! This rocket only understands a few commands so far.",
                             hint: "Try launch(), move(...), repeat, or if.")
        }
        if let suggestion = Suggestions.closest(to: word, in: Self.commands) {
            let example = suggestion == "launch" ? "launch()" : suggestion == "move" ? "move(up)" : suggestion
            return CodeError(line: line, "The rocket doesn't know \"\(word)\".", hint: "Did you mean \(example)?")
        }
        return CodeError(line: line, "The rocket doesn't know \"\(word)\".", hint: "It understands launch(), move(...), repeat, and if.")
    }

    private func unexpected(_ token: Token) -> CodeError {
        switch token.kind {
        case .number:
            CodeError(line: token.line, "A number on its own doesn't do anything.", hint: "Numbers go after repeat, like: repeat 3 {")
        case .leftBrace:
            CodeError(line: token.line, "This { isn't attached to a repeat or if.", hint: "Put it at the end of a repeat or if line.")
        case .leftParen, .rightParen:
            CodeError(line: token.line, "This parenthesis is out of place.", hint: "Parentheses go right after a command, like move(up).")
        case .symbol("."):
            CodeError(line: token.line, "Commands don't need a dot.", hint: "Just write the command, like move(up).")
        case .symbol(let character):
            CodeError(line: token.line, "The rocket doesn't understand the symbol \"\(character)\".", hint: "Try removing it.")
        default:
            CodeError(line: token.line, "I didn't expect \(token.kind.display) here.", hint: "Each line should start with a command, like move(up).")
        }
    }
}
