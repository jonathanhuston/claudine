/// Tokenizes Claudine source code into a stream of tokens.
public class Lexer {
    private let source: [Character]
    private let fileName: String?
    private var position: Int = 0
    private var line: Int = 1
    private var column: Int = 1
    private var tokens: [Token] = []

    private static let keywords: [String: TokenType] = [
        "let": .let, "var": .var, "fn": .fn, "do": .do, "end": .end,
        "if": .if, "else": .else, "elif": .elif,
        "for": .for, "in": .in, "while": .while,
        "match": .match, "case": .case,
        "return": .return, "struct": .struct,
        "import": .import, "as": .as,
        "try": .try, "catch": .catch,
        "args": .args, "arg": .arg, "option": .option, "flag": .flag,
        "break": .break, "continue": .continue,
        "true": .boolLiteral(true), "false": .boolLiteral(false),
        "nil": .nilLiteral,
        "and": .and, "or": .or, "not": .not,
        "self": .self,
    ]

    public init(source: String, fileName: String? = nil) {
        self.source = Array(source)
        self.fileName = fileName
    }

    public func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        position = 0
        line = 1
        column = 1

        while !isAtEnd {
            try skipWhitespaceAndComments()
            if isAtEnd { break }

            let token = try scanToken()
            tokens.append(token)
        }

        tokens.append(Token(type: .eof, location: currentLocation))
        return tokens
    }

    // MARK: - Scanning

    private func scanToken() throws -> Token {
        let loc = currentLocation
        let ch = advance()

        switch ch {
        case "+": return Token(type: .plus, location: loc)
        case "*": return Token(type: .star, location: loc)
        case "%": return Token(type: .percent, location: loc)
        case "(": return Token(type: .leftParen, location: loc)
        case ")": return Token(type: .rightParen, location: loc)
        case "[": return Token(type: .leftBracket, location: loc)
        case "]": return Token(type: .rightBracket, location: loc)
        case "{": return Token(type: .leftBrace, location: loc)
        case "}": return Token(type: .rightBrace, location: loc)
        case ",": return Token(type: .comma, location: loc)
        case ":": return Token(type: .colon, location: loc)
        case "\n":
            return Token(type: .newline, location: loc)

        case "-":
            return Token(type: .minus, location: loc)

        case ".":
            if check(".") {
                advance()
                return Token(type: .dotDot, location: loc)
            }
            return Token(type: .dot, location: loc)

        case "=":
            if check("=") {
                advance()
                return Token(type: .equalEqual, location: loc)
            }
            if check(">") {
                advance()
                return Token(type: .arrow, location: loc)
            }
            return Token(type: .equal, location: loc)

        case "!":
            if check("=") {
                advance()
                return Token(type: .bangEqual, location: loc)
            }
            throw LexerError.unexpectedCharacter(ch, loc)

        case "<":
            if check("=") {
                advance()
                return Token(type: .lessEqual, location: loc)
            }
            return Token(type: .less, location: loc)

        case ">":
            if check("=") {
                advance()
                return Token(type: .greaterEqual, location: loc)
            }
            return Token(type: .greater, location: loc)

        case "|":
            if check(">") {
                advance()
                return Token(type: .pipeline, location: loc)
            }
            throw LexerError.unexpectedCharacter(ch, loc)

        case "/":
            return Token(type: .slash, location: loc)

        case "\"":
            return try scanString(location: loc)

        default:
            if ch.isNumber {
                return try scanNumber(start: ch, location: loc)
            }
            if ch.isIdentifierStart {
                return scanIdentifierOrKeyword(start: ch, location: loc)
            }
            throw LexerError.unexpectedCharacter(ch, loc)
        }
    }

    // MARK: - String Scanning

    private func scanString(location: SourceLocation) throws -> Token {
        var parts: [StringPart] = []
        var current = ""

        while !isAtEnd && peek() != "\"" {
            if peek() == "\\" {
                advance() // consume backslash
                if isAtEnd {
                    throw LexerError.unterminatedString(location)
                }
                let escaped = advance()
                switch escaped {
                case "n": current.append("\n")
                case "t": current.append("\t")
                case "r": current.append("\r")
                case "\\": current.append("\\")
                case "\"": current.append("\"")
                case "{": current.append("{")
                default:
                    throw LexerError.invalidEscapeSequence(escaped, currentLocation)
                }
            } else if peek() == "{" {
                advance() // consume {
                if !current.isEmpty {
                    parts.append(.literal(current))
                    current = ""
                }
                var expr = ""
                var braceDepth = 1
                while !isAtEnd && braceDepth > 0 {
                    let c = advance()
                    if c == "{" { braceDepth += 1 }
                    if c == "}" { braceDepth -= 1 }
                    if braceDepth > 0 { expr.append(c) }
                }
                if braceDepth > 0 {
                    throw LexerError.unterminatedString(location)
                }
                parts.append(.expression(expr))
            } else if peek() == "\n" {
                current.append(advance())
            } else {
                current.append(advance())
            }
        }

        if isAtEnd {
            throw LexerError.unterminatedString(location)
        }
        advance() // consume closing "

        if !current.isEmpty {
            parts.append(.literal(current))
        }

        // If there are no interpolations, return a plain string
        let hasExpressions = parts.contains { if case .expression = $0 { return true } else { return false } }
        if !hasExpressions {
            let full = parts.map { if case .literal(let s) = $0 { return s } else { return "" } }.joined()
            return Token(type: .stringLiteral(full), location: location)
        }

        return Token(type: .interpolatedString(parts), location: location)
    }

    // MARK: - Number Scanning

    private func scanNumber(start: Character, location: SourceLocation) throws -> Token {
        var text = String(start)
        var isFloat = false

        while !isAtEnd && (peek().isNumber || peek() == "." || peek() == "_") {
            if peek() == "." {
                // Check for .. (range operator)
                if position + 1 < source.count && source[position + 1] == "." {
                    break
                }
                if isFloat {
                    break // Second dot — stop
                }
                isFloat = true
            }
            if peek() != "_" {
                text.append(peek())
            }
            advance()
        }

        if isFloat {
            guard let value = Double(text) else {
                throw LexerError.invalidNumberLiteral(text, location)
            }
            return Token(type: .floatLiteral(value), location: location)
        } else {
            guard let value = Int(text) else {
                throw LexerError.invalidNumberLiteral(text, location)
            }
            return Token(type: .intLiteral(value), location: location)
        }
    }

    // MARK: - Identifier / Keyword Scanning

    private func scanIdentifierOrKeyword(start: Character, location: SourceLocation) -> Token {
        var text = String(start)
        while !isAtEnd && peek().isIdentifierContinue {
            text.append(advance())
        }

        if let keyword = Lexer.keywords[text] {
            return Token(type: keyword, location: location)
        }
        return Token(type: .identifier(text), location: location)
    }

    // MARK: - Whitespace & Comments

    private func skipWhitespaceAndComments() throws {
        while !isAtEnd {
            let ch = peek()

            // Skip spaces and tabs (not newlines — they're tokens)
            if ch == " " || ch == "\t" || ch == "\r" {
                advance()
                continue
            }

            // Single-line comment
            if ch == "#" && !(position + 1 < source.count && source[position + 1] == "=") {
                while !isAtEnd && peek() != "\n" {
                    advance()
                }
                continue
            }

            // Multi-line comment #= ... =#
            if ch == "#" && position + 1 < source.count && source[position + 1] == "=" {
                advance() // #
                advance() // =
                while !isAtEnd {
                    if peek() == "=" && position + 1 < source.count && source[position + 1] == "#" {
                        advance() // =
                        advance() // #
                        break
                    }
                    if peek() == "\n" {
                        line += 1
                        column = 0
                    }
                    advance()
                }
                if isAtEnd && !(source.count >= 2 && source[source.count - 2] == "=" && source[source.count - 1] == "#") {
                    // Already consumed past end without finding =#
                    // Check if we actually ended properly
                }
                continue
            }

            break
        }
    }

    // MARK: - Helpers

    private var isAtEnd: Bool { position >= source.count }

    private var currentLocation: SourceLocation {
        SourceLocation(line: line, column: column, file: fileName)
    }

    private func peek() -> Character {
        guard position < source.count else { return "\0" }
        return source[position]
    }

    @discardableResult
    private func advance() -> Character {
        let ch = source[position]
        position += 1
        if ch == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        return ch
    }

    private func check(_ expected: Character) -> Bool {
        guard !isAtEnd && peek() == expected else { return false }
        return true
    }
}

// MARK: - Character Extensions

extension Character {
    var isIdentifierStart: Bool {
        self.isLetter || self == "_"
    }

    var isIdentifierContinue: Bool {
        self.isLetter || self.isNumber || self == "_"
    }
}
