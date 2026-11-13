//
//  Parser.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import Foundation

// Turning code into something the rocket understands happens in two steps:
// 1. The Lexer chops the text into tokens: words, numbers, and symbols like ( and :.
//    Each token also remembers how far its line is indented.
// 2. The Parser reads those tokens and builds a tree of Statements. Like Python, RocketScript
//    groups lines by indentation: the indented lines under `repeat 3 times:` belong to the repeat.
// Every error is written for a beginner: what went wrong, and how to fix it.

enum TokenKind: Equatable {
    case identifier(String)
    case number(Int)
    case leftParen, rightParen, leftBrace, rightBrace, comma, colon
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
        case .colon: ":"
        case .newline: "the end of the line"
        case .symbol(let character): "\"\(character)\""
        case .end: "the end of your code"
        }
    }
}

struct Token: Equatable {
    let kind: TokenKind
    let line: Int
    /// How many spaces start this token's line (a tab counts as four).
    var indent = 0
}

enum Lexer {
    static func tokenize(_ source: String) -> [Token] {
        var tokens: [Token] = []
        let characters = Array(source)
        var line = 1
        var index = 0
        var indent = 0
        var atLineStart = true

        while index < characters.count {
            let character = characters[index]

            if character == "\n" || character == ";" {
                tokens.append(Token(kind: .newline, line: line))
                if character == "\n" {
                    line += 1
                    indent = 0
                    atLineStart = true
                }
                index += 1
            } else if character.isWhitespace {
                if atLineStart { indent += character == "\t" ? 4 : 1 }
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
                tokens.append(Token(kind: .identifier(word), line: line, indent: indent))
                atLineStart = false
            } else if character.isASCIINumber {
                var digits = ""
                while index < characters.count, characters[index].isASCIINumber {
                    digits.append(characters[index])
                    index += 1
                }
                tokens.append(Token(kind: .number(Int(digits) ?? Int.max), line: line, indent: indent))
                atLineStart = false
            } else {
                let kind: TokenKind = switch character {
                case "(": .leftParen
                case ")": .rightParen
                case "{": .leftBrace
                case "}": .rightBrace
                case ",": .comma
                case ":": .colon
                default: .symbol(character)
                }
                tokens.append(Token(kind: kind, line: line, indent: indent))
                atLineStart = false
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
    static let actions = ["launch", "orbit", "explore", "land", "move"]
    static let commands = ["create"] + actions + ["repeat", "if", "else"]

    private let tokens: [Token]
    private var position = 0

    private init(tokens: [Token]) {
        self.tokens = tokens
    }

    static func parse(_ source: String) -> Result<[Statement], CodeError> {
        var parser = Parser(tokens: Lexer.tokenize(source))
        do {
            return .success(try parser.parseBlock(under: nil))
        } catch {
            return .failure(error)
        }
    }

    /// A line of RocketScript that shows how a command is written, for hints.
    static func example(for command: String) -> String {
        switch command {
        case "create": "create rocket"
        case "move": "move up"
        case "repeat": "repeat 3 times:"
        case "if": "if moon:"
        default: command
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

    /// Looks ahead past blank lines without moving, so `else` can be found on a later line.
    private func peekPastNewlines() -> Token {
        var index = position
        while tokens[index].kind == .newline { index += 1 }
        return tokens[index]
    }

    // MARK: - Blocks and statements

    /// Reads statements until the code ends. Inside a repeat or if (`header` is that line's
    /// indent), it stops at the first line that isn't indented further than the header.
    private mutating func parseBlock(under header: Int?) throws(CodeError) -> [Statement] {
        var statements: [Statement] = []
        while true {
            skipNewlines()
            if current.kind == .end { return statements }
            if let header, current.indent <= header { return statements }
            statements.append(try parseStatement())
            try expectEndOfStatement()
        }
    }

    private func expectEndOfStatement() throws(CodeError) {
        // A repeat or if body already ran onto the next line.
        if position > 0, tokens[position - 1].kind == .newline { return }
        switch current.kind {
        case .newline, .end:
            return
        case .leftBrace, .rightBrace:
            throw Self.braceError(line: current.line)
        default:
            throw CodeError(line: current.line, "Let's give each command its own line.",
                            hint: "Press return before \(current.kind.display).")
        }
    }

    private static func braceError(line: Int) -> CodeError {
        CodeError(line: line, "No curly braces needed in RocketScript!",
                  hint: "End the line with a colon, then indent the lines underneath. Like: repeat 3 times:")
    }

    /// The body of a repeat or if: the rest of the same line (`repeat 3 times: move up`),
    /// or the indented lines below it.
    private mutating func parseBody(of header: Token, name: String) throws(CodeError) -> [Statement] {
        if current.kind == .colon { advance() }
        if current.kind == .leftBrace { throw Self.braceError(line: header.line) }
        if current.kind != .newline && current.kind != .end {
            return [try parseStatement()]
        }
        let body = try parseBlock(under: header.indent)
        guard !body.isEmpty else {
            throw CodeError(line: header.line, "\(name) needs something to do.",
                            hint: "Put the commands on the next lines, with a few spaces in front.")
        }
        return body
    }

    private mutating func parseStatement() throws(CodeError) -> Statement {
        let token = current
        guard case .identifier(let word) = token.kind else {
            throw unexpected(token)
        }
        switch word {
        case "create":
            advance()
            return .make(try parseThing(line: token.line), line: token.line)
        case "launch", "orbit", "explore", "land":
            advance()
            try parseEmptyArguments(for: word, line: token.line)
            switch word {
            case "launch": return .launch(line: token.line)
            case "orbit": return .orbit(line: token.line)
            case "land": return .land(line: token.line)
            default: return .explore(line: token.line)
            }
        case "move":
            advance()
            return .move(try parseDirection(line: token.line), line: token.line)
        case "repeat":
            advance()
            return try parseRepeat(token)
        case "if":
            advance()
            return try parseIf(token)
        case "else":
            throw CodeError(line: token.line, "This else is looking for its if.",
                            hint: "else goes on its own line, lined up with an if above it.")
        case "hello", "hi", "Hello", "Hi":
            advance()
            try parseEmptyArguments(for: word, line: token.line)
            return .easterEgg(.hello, line: token.line)
        case "help":
            advance()
            try parseEmptyArguments(for: word, line: token.line)
            return .easterEgg(.help, line: token.line)
        case "suitUp", "stargaze":
            advance()
            try parseEmptyArguments(for: word, line: token.line)
            return .easterEgg(word == "suitUp" ? .suitUp : .stargaze, line: token.line)
        default:
            throw unknownWord(word, line: token.line)
        }
    }

    /// `launch` and `launch()` both work.
    private mutating func parseEmptyArguments(for name: String, line: Int) throws(CodeError) {
        guard current.kind == .leftParen else { return }
        advance()
        guard current.kind == .rightParen else {
            throw CodeError(line: line, "\(name) doesn't need anything after it.", hint: "Just write \(name).")
        }
        advance()
    }

    /// Reads the word after a command. `create planet`, `create a planet`, and `create(planet)` all work.
    private mutating func parseArgument(line: Int, example: String) throws(CodeError) -> String? {
        let hasParenthesis = current.kind == .leftParen
        if hasParenthesis { advance() }
        if case .identifier(let word) = current.kind, ["a", "an", "the"].contains(word.lowercased()) { advance() }
        var word: String?
        if case .identifier(let found) = current.kind {
            word = found
            advance()
        }
        if hasParenthesis {
            guard current.kind == .rightParen else {
                throw CodeError(line: line, "That ( is missing its ).", hint: "Or skip the parentheses: \(example).")
            }
            advance()
        }
        return word
    }

    private mutating func parseThing(line: Int) throws(CodeError) -> Thing {
        let choices = "Try create planet, or any of these: \(Thing.allCases.map(\.rawValue).joined(separator: ", "))."
        guard let word = try parseArgument(line: line, example: "create planet") else {
            throw CodeError(line: line, "What should we create?", hint: choices)
        }
        guard let thing = Thing(rawValue: word) else {
            throw unknownThing(word, line: line)
        }
        return thing
    }

    private func unknownThing(_ word: String, line: Int) -> CodeError {
        let lowered = word.lowercased()
        if let thing = Thing(rawValue: lowered) {
            return CodeError(line: line, "Things like to be lowercase.", hint: "Try create \(thing.rawValue).")
        }
        if lowered.hasSuffix("s"), let thing = Thing(rawValue: String(lowered.dropLast())) {
            return CodeError(line: line, "One at a time! \"\(word)\" is plural.",
                             hint: "Try create \(thing.rawValue). Want several? Try repeat 3 times: create \(thing.rawValue)")
        }
        if ["earth", "mars", "jupiter", "saturn"].contains(lowered) {
            return CodeError(line: line, "Planets pick their own names.", hint: "Just ask for one: create planet.")
        }
        if lowered == "sun" {
            return CodeError(line: line, "The sun is a star!", hint: "Try create star.")
        }
        if ["ship", "spaceship", "shuttle"].contains(lowered) {
            return CodeError(line: line, "That sounds like a rocket to me.", hint: "Try create rocket.")
        }
        let suggestion = Suggestions.closest(to: word, in: Thing.allCases.map(\.rawValue))
        return CodeError(line: line, "Hmm, what's a \"\(word)\"? I'd love to find out!",
                         hint: suggestion.map { "Did you mean create \($0)?" }
                            ?? "I know these: \(Thing.allCases.map(\.rawValue).joined(separator: ", ")).")
    }

    private mutating func parseDirection(line: Int) throws(CodeError) -> Direction {
        let choices = "Try move up, move down, move left, or move right."
        guard let word = try parseArgument(line: line, example: "move up") else {
            throw CodeError(line: line, "Which way?", hint: choices)
        }
        guard let direction = Direction(rawValue: word) else {
            if let direction = Direction(rawValue: word.lowercased()) {
                throw CodeError(line: line, "Directions like to be lowercase.", hint: "Try move \(direction.rawValue).")
            }
            let suggestion = Suggestions.closest(to: word, in: Direction.allCases.map(\.rawValue))
            throw CodeError(line: line, "Which way is \"\(word)\"?",
                            hint: suggestion.map { "Did you mean move \($0)?" } ?? choices)
        }
        return direction
    }

    /// `repeat 3 times:`, `repeat 3:`, and `repeat(3)` all work.
    private mutating func parseRepeat(_ header: Token) throws(CodeError) -> Statement {
        let hasParenthesis = current.kind == .leftParen
        if hasParenthesis { advance() }
        guard case .number(let count) = current.kind else {
            throw CodeError(line: header.line, "How many times?", hint: "Pop a number after repeat, like: repeat 3 times:")
        }
        advance()
        if hasParenthesis {
            guard current.kind == .rightParen else {
                throw CodeError(line: header.line, "That ( is missing its ).", hint: "Or just write: repeat \(count) times:")
            }
            advance()
        }
        if case .identifier(let word) = current.kind, word == "times" || word == "time" { advance() }
        return .repeatLoop(count: count, body: try parseBody(of: header, name: "repeat"), line: header.line)
    }

    /// `if moon:`, `if not moon:`, with an optional `else:` lined up underneath.
    private mutating func parseIf(_ header: Token) throws(CodeError) -> Statement {
        let hasParenthesis = current.kind == .leftParen
        if hasParenthesis { advance() }

        // `if not moon` and `if !moon` both ask "is there no moon?"
        var negated = false
        if case .identifier("not") = current.kind {
            negated = true
            advance()
        } else if case .symbol("!") = current.kind {
            negated = true
            advance()
        }
        if case .identifier(let word) = current.kind, ["a", "an", "the"].contains(word) { advance() }

        guard case .identifier(let word) = current.kind else {
            throw CodeError(line: header.line, "What should we check for?", hint: "Try: if moon: or if not moon:")
        }
        guard let thing = Thing(rawValue: word) else {
            let suggestion = Suggestions.closest(to: word, in: Thing.allCases.map(\.rawValue))
            throw CodeError(line: header.line, "I can't check for a \"\(word)\". What is it?",
                            hint: suggestion.map { "Did you mean if \($0):?" } ?? "Try: if moon: or if asteroid:")
        }
        advance()
        let condition = Condition(thing: thing, negated: negated)

        if hasParenthesis {
            guard current.kind == .rightParen else {
                throw CodeError(line: header.line, "That ( is missing its ).", hint: "Or just write: if \(condition.text):")
            }
            advance()
        }

        let thenBody = try parseBody(of: header, name: "if")

        var elseBody: [Statement]?
        let next = peekPastNewlines()
        if case .identifier("else") = next.kind, next.indent == header.indent {
            skipNewlines()
            let elseToken = current
            advance()
            if case .identifier("if") = current.kind {
                let nested = current
                advance()
                // `else if` sits at the else's indent, so its body is indented under that.
                elseBody = [try parseIf(Token(kind: nested.kind, line: nested.line, indent: elseToken.indent))]
            } else {
                elseBody = try parseBody(of: elseToken, name: "else")
            }
        }
        return .ifElse(condition, then: thenBody, otherwise: elseBody, line: header.line)
    }

    // MARK: - Friendly errors

    private func unknownWord(_ word: String, line: Int) -> CodeError {
        let lowered = word.lowercased()

        if Self.commands.contains(lowered) {
            return CodeError(line: line, "RocketScript likes lowercase letters.", hint: "Try \(Self.example(for: lowered)).")
        }
        if let thing = Thing(rawValue: lowered) {
            return CodeError(line: line, "A \(lowered)! Which command makes one?", hint: "Try create \(thing.rawValue).")
        }
        if lowered.hasSuffix("s"), let thing = Thing(rawValue: String(lowered.dropLast())) {
            return CodeError(line: line, "Let's make those one at a time.",
                             hint: "Try repeat 3 times: create \(thing.rawValue)")
        }
        if let direction = Direction(rawValue: lowered) {
            return CodeError(line: line, "Which command goes \(lowered)?", hint: "Try move \(direction.rawValue).")
        }
        if let direction = Direction.allCases.first(where: { lowered == "move" + $0.rawValue }) {
            return CodeError(line: line, "So close! Add a space.", hint: "Like this: move \(direction.rawValue).")
        }
        if let thing = Thing.allCases.first(where: { lowered == "create" + $0.rawValue }) {
            return CodeError(line: line, "So close! Add a space.", hint: "Like this: create \(thing.rawValue).")
        }
        if lowered == "suitup" || lowered == "stargaze" {
            let name = lowered == "suitup" ? "suitUp" : "stargaze"
            return CodeError(line: line, "Ooh, you're onto something secret...", hint: "Try writing it exactly as \(name).")
        }
        if ["make", "build", "spawn", "summon", "add", "place", "put", "new", "generate"].contains(lowered) {
            return CodeError(line: line, "I think the word you want is create!", hint: "Like this: create planet.")
        }
        if ["fly", "go", "land", "takeoff", "liftoff"].contains(lowered) {
            return CodeError(line: line, "Hmm, maybe you mean launch?", hint: "launch sends your rocket up.")
        }
        if ["for", "while", "func", "let", "var", "print", "return", "switch", "guard"].contains(word) {
            return CodeError(line: line, "Ooh, \"\(word)\" is real Swift! RocketScript doesn't know it yet.",
                             hint: "I know create, launch, orbit, explore, land, move, repeat, and if.")
        }
        if let suggestion = Suggestions.closest(to: word, in: Self.commands) {
            return CodeError(line: line, "Hmm, \"\(word)\" is new to me.", hint: "Did you mean \(Self.example(for: suggestion))?")
        }
        return CodeError(line: line, "Hmm, \"\(word)\" is new to me.", hint: "Try create planet, launch, or repeat 3 times:")
    }

    private func unexpected(_ token: Token) -> CodeError {
        switch token.kind {
        case .number:
            CodeError(line: token.line, "A number on its own doesn't do anything.", hint: "Numbers go after repeat, like: repeat 3 times:")
        case .leftBrace, .rightBrace:
            Self.braceError(line: token.line)
        case .leftParen, .rightParen:
            CodeError(line: token.line, "This parenthesis wandered off.", hint: "RocketScript doesn't need them. Try create rocket.")
        case .colon:
            CodeError(line: token.line, "A colon goes at the end of a repeat or if line.", hint: "Like: repeat 3 times:")
        case .symbol("."):
            CodeError(line: token.line, "No dots needed here!", hint: "Just the command, like create rocket.")
        case .symbol(let character):
            CodeError(line: token.line, "Not sure what \"\(character)\" means here.", hint: "Try removing it.")
        default:
            CodeError(line: token.line, "I didn't expect \(token.kind.display) here.", hint: "Start the line with a command, like create rocket.")
        }
    }
}
