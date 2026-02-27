/// AST expression nodes for Claudine.
public indirect enum Expression {
    case intLiteral(Int, SourceLocation)
    case floatLiteral(Double, SourceLocation)
    case stringLiteral(String, SourceLocation)
    case interpolatedString([InterpolationPart], SourceLocation)
    case boolLiteral(Bool, SourceLocation)
    case nilLiteral(SourceLocation)
    case identifier(String, SourceLocation)
    case selfExpr(SourceLocation)

    // Collections
    case listLiteral([Expression], SourceLocation)
    case mapLiteral([(String, Expression)], SourceLocation)

    // Operators
    case binary(Expression, BinaryOp, Expression, SourceLocation)
    case unary(UnaryOp, Expression, SourceLocation)
    case pipeline(Expression, Expression, SourceLocation)

    // Access
    case call(Expression, [CallArgument], SourceLocation)
    case index(Expression, Expression, SourceLocation)
    case fieldAccess(Expression, String, SourceLocation)

    // Assignment expression
    case assign(Expression, Expression, SourceLocation)

    // Lambda
    case lambda([FunctionParam], [Statement], Bool, SourceLocation)  // params, body, isShorthand

    // Range
    case range(Expression, Expression, SourceLocation)

    public var location: SourceLocation {
        switch self {
        case .intLiteral(_, let loc), .floatLiteral(_, let loc),
             .stringLiteral(_, let loc), .interpolatedString(_, let loc),
             .boolLiteral(_, let loc), .nilLiteral(let loc),
             .identifier(_, let loc), .selfExpr(let loc),
             .listLiteral(_, let loc), .mapLiteral(_, let loc),
             .binary(_, _, _, let loc), .unary(_, _, let loc),
             .pipeline(_, _, let loc),
             .call(_, _, let loc), .index(_, _, let loc),
             .fieldAccess(_, _, let loc),
             .assign(_, _, let loc),
             .lambda(_, _, _, let loc),
             .range(_, _, let loc):
            return loc
        }
    }
}

extension Expression: Equatable {
    public static func == (lhs: Expression, rhs: Expression) -> Bool {
        switch (lhs, rhs) {
        case (.intLiteral(let a, _), .intLiteral(let b, _)): return a == b
        case (.floatLiteral(let a, _), .floatLiteral(let b, _)): return a == b
        case (.stringLiteral(let a, _), .stringLiteral(let b, _)): return a == b
        case (.interpolatedString(let a, _), .interpolatedString(let b, _)): return a == b
        case (.boolLiteral(let a, _), .boolLiteral(let b, _)): return a == b
        case (.nilLiteral, .nilLiteral): return true
        case (.identifier(let a, _), .identifier(let b, _)): return a == b
        case (.selfExpr, .selfExpr): return true
        case (.listLiteral(let a, _), .listLiteral(let b, _)): return a == b
        case (.mapLiteral(let a, _), .mapLiteral(let b, _)):
            guard a.count == b.count else { return false }
            return zip(a, b).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        case (.binary(let la, let oa, let ra, _), .binary(let lb, let ob, let rb, _)):
            return la == lb && oa == ob && ra == rb
        case (.unary(let oa, let ea, _), .unary(let ob, let eb, _)):
            return oa == ob && ea == eb
        case (.pipeline(let la, let ra, _), .pipeline(let lb, let rb, _)):
            return la == lb && ra == rb
        case (.call(let ca, let aa, _), .call(let cb, let ab, _)):
            return ca == cb && aa == ab
        case (.index(let oa, let ia, _), .index(let ob, let ib, _)):
            return oa == ob && ia == ib
        case (.fieldAccess(let oa, let fa, _), .fieldAccess(let ob, let fb, _)):
            return oa == ob && fa == fb
        case (.assign(let ta, let va, _), .assign(let tb, let vb, _)):
            return ta == tb && va == vb
        case (.lambda(let pa, let ba, let sa, _), .lambda(let pb, let bb, let sb, _)):
            return pa == pb && ba == bb && sa == sb
        case (.range(let sa, let ea, _), .range(let sb, let eb, _)):
            return sa == sb && ea == eb
        default: return false
        }
    }
}

/// A call argument (positional or named).
public struct CallArgument: Equatable {
    public let label: String?
    public let value: Expression

    public init(label: String? = nil, value: Expression) {
        self.label = label
        self.value = value
    }
}

/// Part of an interpolated string in the AST.
public enum InterpolationPart: Equatable {
    case literal(String)
    case expression(Expression)
}

/// Binary operators.
public enum BinaryOp: String, Equatable {
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"
    case modulo = "%"
    case equal = "=="
    case notEqual = "!="
    case less = "<"
    case lessEqual = "<="
    case greater = ">"
    case greaterEqual = ">="
    case and = "and"
    case or = "or"
}

/// Unary operators.
public enum UnaryOp: String, Equatable {
    case negate = "-"
    case not = "not"
}

/// AST statement nodes for Claudine.
public indirect enum Statement {
    case expression(Expression)
    case letDecl(String, Expression, SourceLocation)
    case varDecl(String, Expression, SourceLocation)
    case fnDecl(String, [FunctionParam], [Statement], Bool, SourceLocation) // name, params, body, isShorthand
    case ifStmt(Expression, [Statement], [(Expression, [Statement])], [Statement]?, SourceLocation) // condition, body, elifs, else
    case forStmt(String, Expression, [Statement], SourceLocation) // variable, iterable, body
    case whileStmt(Expression, [Statement], SourceLocation)
    case matchStmt(Expression, [MatchCase], SourceLocation)
    case returnStmt(Expression?, SourceLocation)
    case breakStmt(SourceLocation)
    case continueStmt(SourceLocation)
    case structDecl(String, [String], [Statement], SourceLocation) // name, fields, methods
    case importStmt(String, String?, SourceLocation) // path, alias
    case tryCatch([Statement], String, [Statement], SourceLocation) // tryBody, errorVar, catchBody
    case argsBlock([ArgDef], SourceLocation)

    public var location: SourceLocation {
        switch self {
        case .expression(let e): return e.location
        case .letDecl(_, _, let loc), .varDecl(_, _, let loc),
             .fnDecl(_, _, _, _, let loc),
             .ifStmt(_, _, _, _, let loc),
             .forStmt(_, _, _, let loc), .whileStmt(_, _, let loc),
             .matchStmt(_, _, let loc),
             .returnStmt(_, let loc),
             .breakStmt(let loc), .continueStmt(let loc),
             .structDecl(_, _, _, let loc),
             .importStmt(_, _, let loc),
             .tryCatch(_, _, _, let loc),
             .argsBlock(_, let loc):
            return loc
        }
    }
}

extension Statement: Equatable {
    public static func == (lhs: Statement, rhs: Statement) -> Bool {
        switch (lhs, rhs) {
        case (.expression(let a), .expression(let b)): return a == b
        case (.letDecl(let na, let ea, _), .letDecl(let nb, let eb, _)): return na == nb && ea == eb
        case (.varDecl(let na, let ea, _), .varDecl(let nb, let eb, _)): return na == nb && ea == eb
        case (.fnDecl(let na, let pa, let ba, let sa, _), .fnDecl(let nb, let pb, let bb, let sb, _)):
            return na == nb && pa == pb && ba == bb && sa == sb
        case (.ifStmt(let ca, let ba, let ea, let ela, _), .ifStmt(let cb, let bb, let eb, let elb, _)):
            guard ca == cb && ba == bb && ela == elb else { return false }
            guard ea.count == eb.count else { return false }
            return zip(ea, eb).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        case (.forStmt(let va, let ia, let ba, _), .forStmt(let vb, let ib, let bb, _)):
            return va == vb && ia == ib && ba == bb
        case (.whileStmt(let ca, let ba, _), .whileStmt(let cb, let bb, _)):
            return ca == cb && ba == bb
        case (.matchStmt(let ea, let ca, _), .matchStmt(let eb, let cb, _)):
            return ea == eb && ca == cb
        case (.returnStmt(let a, _), .returnStmt(let b, _)): return a == b
        case (.breakStmt, .breakStmt): return true
        case (.continueStmt, .continueStmt): return true
        case (.structDecl(let na, let fa, let ma, _), .structDecl(let nb, let fb, let mb, _)):
            return na == nb && fa == fb && ma == mb
        case (.importStmt(let pa, let aa, _), .importStmt(let pb, let ab, _)):
            return pa == pb && aa == ab
        case (.tryCatch(let ta, let ea, let ca, _), .tryCatch(let tb, let eb, let cb, _)):
            return ta == tb && ea == eb && ca == cb
        case (.argsBlock(let a, _), .argsBlock(let b, _)): return a == b
        default: return false
        }
    }
}

/// A match/case pattern.
public enum Pattern: Equatable {
    case literal(Expression)
    case range(Expression, Expression)
    case variable(String, SourceLocation)

    public static func == (lhs: Pattern, rhs: Pattern) -> Bool {
        switch (lhs, rhs) {
        case (.literal(let a), .literal(let b)): return a == b
        case (.range(let sa, let ea), .range(let sb, let eb)): return sa == sb && ea == eb
        case (.variable(let a, _), .variable(let b, _)): return a == b
        default: return false
        }
    }
}

/// A single case in a match statement.
public struct MatchCase: Equatable {
    public let pattern: Pattern
    public let body: [Statement]

    public init(pattern: Pattern, body: [Statement]) {
        self.pattern = pattern
        self.body = body
    }
}

/// Argument definition in an args block.
public enum ArgDef: Equatable {
    case positional(name: String, type: String, description: String)
    case option(name: String, type: String, description: String, defaultValue: Expression?)
    case flag(name: String, description: String, short: String?)
}
