/// Source location for error reporting.
public struct SourceLocation: Equatable, CustomStringConvertible {
    public let line: Int
    public let column: Int
    public let file: String?

    public init(line: Int, column: Int, file: String? = nil) {
        self.line = line
        self.column = column
        self.file = file
    }

    public var description: String {
        let prefix = file.map { "\($0):" } ?? ""
        return "\(prefix)\(line):\(column)"
    }
}

/// Errors raised by the Claudine lexer.
public enum LexerError: Error, CustomStringConvertible {
    case unexpectedCharacter(Character, SourceLocation)
    case unterminatedString(SourceLocation)
    case unterminatedMultiLineComment(SourceLocation)
    case invalidEscapeSequence(Character, SourceLocation)
    case invalidNumberLiteral(String, SourceLocation)

    public var description: String {
        switch self {
        case .unexpectedCharacter(let ch, let loc):
            return "\(loc): unexpected character '\(ch)'"
        case .unterminatedString(let loc):
            return "\(loc): unterminated string literal"
        case .unterminatedMultiLineComment(let loc):
            return "\(loc): unterminated multi-line comment"
        case .invalidEscapeSequence(let ch, let loc):
            return "\(loc): invalid escape sequence '\\(\(ch))'"
        case .invalidNumberLiteral(let text, let loc):
            return "\(loc): invalid number literal '\(text)'"
        }
    }
}

/// Errors raised by the Claudine parser.
public enum ParseError: Error, CustomStringConvertible {
    case unexpectedToken(Token, expected: String)
    case unexpectedEOF(expected: String)
    case invalidAssignmentTarget(SourceLocation)
    case expectedExpression(Token)

    public var description: String {
        switch self {
        case .unexpectedToken(let token, let expected):
            return "\(token.location): unexpected \(token.type), expected \(expected)"
        case .unexpectedEOF(let expected):
            return "unexpected end of file, expected \(expected)"
        case .invalidAssignmentTarget(let loc):
            return "\(loc): invalid assignment target"
        case .expectedExpression(let token):
            return "\(token.location): expected expression, got \(token.type)"
        }
    }
}

/// Errors raised at runtime by the Claudine interpreter.
public enum RuntimeError: Error, CustomStringConvertible {
    case undefinedVariable(String, SourceLocation?)
    case typeMismatch(expected: String, got: String, SourceLocation?)
    case divisionByZero(SourceLocation?)
    case indexOutOfBounds(Int, count: Int, SourceLocation?)
    case notCallable(String, SourceLocation?)
    case arityMismatch(expected: Int, got: Int, SourceLocation?)
    case immutableVariable(String, SourceLocation?)
    case undefinedProperty(String, SourceLocation?)
    case notIterable(String, SourceLocation?)
    case fileError(String, SourceLocation?)
    case networkError(String, SourceLocation?)
    case importError(String, SourceLocation?)
    case returnValue(Value)
    case breakSignal
    case continueSignal
    case userThrownError(Value, SourceLocation?)
    case generalError(String, SourceLocation?)

    public var description: String {
        switch self {
        case .undefinedVariable(let name, let loc):
            return "\(loc.map { "\($0): " } ?? "")undefined variable '\(name)'"
        case .typeMismatch(let expected, let got, let loc):
            return "\(loc.map { "\($0): " } ?? "")type mismatch: expected \(expected), got \(got)"
        case .divisionByZero(let loc):
            return "\(loc.map { "\($0): " } ?? "")division by zero"
        case .indexOutOfBounds(let index, let count, let loc):
            return "\(loc.map { "\($0): " } ?? "")index \(index) out of bounds (count: \(count))"
        case .notCallable(let type, let loc):
            return "\(loc.map { "\($0): " } ?? "")'\(type)' is not callable"
        case .arityMismatch(let expected, let got, let loc):
            return "\(loc.map { "\($0): " } ?? "")expected \(expected) argument(s), got \(got)"
        case .immutableVariable(let name, let loc):
            return "\(loc.map { "\($0): " } ?? "")cannot assign to immutable variable '\(name)'"
        case .undefinedProperty(let name, let loc):
            return "\(loc.map { "\($0): " } ?? "")undefined property '\(name)'"
        case .notIterable(let type, let loc):
            return "\(loc.map { "\($0): " } ?? "")'\(type)' is not iterable"
        case .fileError(let msg, let loc):
            return "\(loc.map { "\($0): " } ?? "")file error: \(msg)"
        case .networkError(let msg, let loc):
            return "\(loc.map { "\($0): " } ?? "")network error: \(msg)"
        case .importError(let msg, let loc):
            return "\(loc.map { "\($0): " } ?? "")import error: \(msg)"
        case .returnValue:
            return "return outside of function"
        case .breakSignal:
            return "break outside of loop"
        case .continueSignal:
            return "continue outside of loop"
        case .userThrownError(let value, let loc):
            return "\(loc.map { "\($0): " } ?? "")\(value)"
        case .generalError(let msg, let loc):
            return "\(loc.map { "\($0): " } ?? "")\(msg)"
        }
    }
}
