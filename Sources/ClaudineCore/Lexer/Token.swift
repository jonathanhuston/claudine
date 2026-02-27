/// Represents the type of a Claudine token.
public enum TokenType: Equatable, CustomStringConvertible {
    // Literals
    case intLiteral(Int)
    case floatLiteral(Double)
    case stringLiteral(String)
    case interpolatedString([StringPart])
    case boolLiteral(Bool)
    case nilLiteral

    // Identifier
    case identifier(String)

    // Keywords
    case `let`
    case `var`
    case `fn`
    case `do`
    case end
    case `if`
    case `else`
    case elif
    case `for`
    case `in`
    case `while`
    case match
    case `case`
    case `return`
    case `struct`
    case `import`
    case `as`
    case `try`
    case `catch`
    case args
    case arg
    case option
    case flag
    case `break`
    case `continue`
    case `self`

    // Operators
    case plus          // +
    case minus         // -
    case star          // *
    case slash         // /
    case percent       // %
    case equal         // =
    case equalEqual    // ==
    case bangEqual     // !=
    case less          // <
    case lessEqual     // <=
    case greater       // >
    case greaterEqual  // >=
    case and           // and
    case or            // or
    case not           // not
    case pipeline      // |>
    case arrow         // =>
    case dotDot        // ..

    // Delimiters
    case leftParen     // (
    case rightParen    // )
    case leftBracket   // [
    case rightBracket  // ]
    case leftBrace     // {
    case rightBrace    // }
    case comma         // ,
    case dot           // .
    case colon         // :
    case newline
    case eof

    public var description: String {
        switch self {
        case .intLiteral(let v): return "int(\(v))"
        case .floatLiteral(let v): return "float(\(v))"
        case .stringLiteral(let v): return "string(\"\(v)\")"
        case .interpolatedString: return "interpolated string"
        case .boolLiteral(let v): return "\(v)"
        case .nilLiteral: return "nil"
        case .identifier(let v): return "identifier(\(v))"
        case .let: return "let"
        case .var: return "var"
        case .fn: return "fn"
        case .do: return "do"
        case .end: return "end"
        case .if: return "if"
        case .else: return "else"
        case .elif: return "elif"
        case .for: return "for"
        case .in: return "in"
        case .while: return "while"
        case .match: return "match"
        case .case: return "case"
        case .return: return "return"
        case .struct: return "struct"
        case .import: return "import"
        case .as: return "as"
        case .try: return "try"
        case .catch: return "catch"
        case .args: return "args"
        case .arg: return "arg"
        case .option: return "option"
        case .flag: return "flag"
        case .break: return "break"
        case .continue: return "continue"
        case .self: return "self"
        case .plus: return "+"
        case .minus: return "-"
        case .star: return "*"
        case .slash: return "/"
        case .percent: return "%"
        case .equal: return "="
        case .equalEqual: return "=="
        case .bangEqual: return "!="
        case .less: return "<"
        case .lessEqual: return "<="
        case .greater: return ">"
        case .greaterEqual: return ">="
        case .and: return "and"
        case .or: return "or"
        case .not: return "not"
        case .pipeline: return "|>"
        case .arrow: return "=>"
        case .dotDot: return ".."
        case .leftParen: return "("
        case .rightParen: return ")"
        case .leftBracket: return "["
        case .rightBracket: return "]"
        case .leftBrace: return "{"
        case .rightBrace: return "}"
        case .comma: return ","
        case .dot: return "."
        case .colon: return ":"
        case .newline: return "newline"
        case .eof: return "EOF"
        }
    }
}

/// A part of an interpolated string.
public enum StringPart: Equatable {
    case literal(String)
    case expression(String)
}

/// A token produced by the Claudine lexer.
public struct Token: Equatable {
    public let type: TokenType
    public let location: SourceLocation

    public init(type: TokenType, location: SourceLocation) {
        self.type = type
        self.location = location
    }
}
