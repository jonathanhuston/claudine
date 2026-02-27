/// Recursive descent parser for Claudine.
public class Parser {
    private let tokens: [Token]
    private let fileName: String?
    private var position: Int = 0

    public init(tokens: [Token], fileName: String? = nil) {
        self.tokens = tokens
        self.fileName = fileName
    }

    public func parse() throws -> [Statement] {
        position = 0
        var statements: [Statement] = []
        skipNewlines()
        while !isAtEnd {
            let stmt = try parseStatement()
            statements.append(stmt)
            skipNewlines()
        }
        return statements
    }

    // MARK: - Statement Parsing

    private func parseStatement() throws -> Statement {
        skipNewlines()
        let token = current

        switch token.type {
        case .let:
            return try parseLetDecl()
        case .var:
            return try parseVarDecl()
        case .fn:
            return try parseFnDecl()
        case .if:
            return try parseIfStmt()
        case .for:
            return try parseForStmt()
        case .while:
            return try parseWhileStmt()
        case .match:
            return try parseMatchStmt()
        case .return:
            return try parseReturnStmt()
        case .break:
            advance()
            return .breakStmt(token.location)
        case .continue:
            advance()
            return .continueStmt(token.location)
        case .struct:
            return try parseStructDecl()
        case .import:
            return try parseImportStmt()
        case .try:
            return try parseTryCatch()
        case .args:
            return try parseArgsBlock()
        default:
            let expr = try parseExpression()
            return .expression(expr)
        }
    }

    private func parseLetDecl() throws -> Statement {
        let loc = current.location
        try expect(.let, "let")
        let name = try expectIdentifier()
        try expect(.equal, "=")
        let value = try parseExpression()
        return .letDecl(name, value, loc)
    }

    private func parseVarDecl() throws -> Statement {
        let loc = current.location
        try expect(.var, "var")
        let name = try expectIdentifier()
        try expect(.equal, "=")
        let value = try parseExpression()
        return .varDecl(name, value, loc)
    }

    private func parseFnDecl() throws -> Statement {
        let loc = current.location
        try expect(.fn, "fn")
        let name = try expectIdentifier()
        let params = try parseParamList()

        if matchToken(.arrow) {
            // Single-expression shorthand: fn name(params) => expr
            let expr = try parseExpression()
            return .fnDecl(name, params, [.expression(expr)], true, loc)
        }

        try expect(.do, "do")
        let body = try parseBlock()
        try expect(.end, "end")
        return .fnDecl(name, params, body, false, loc)
    }

    private func parseParamList() throws -> [FunctionParam] {
        try expect(.leftParen, "(")
        var params: [FunctionParam] = []
        if !check(.rightParen) {
            repeat {
                skipNewlines()
                let name = try expectIdentifier()
                var defaultValue: Expression? = nil
                if matchToken(.equal) {
                    defaultValue = try parseExpression()
                }
                params.append(FunctionParam(name: name, defaultValue: defaultValue))
            } while matchToken(.comma)
        }
        skipNewlines()
        try expect(.rightParen, ")")
        return params
    }

    private func parseIfStmt() throws -> Statement {
        let loc = current.location
        try expect(.if, "if")
        let condition = try parseExpression()
        try expect(.do, "do")
        let body = try parseBlock()

        var elifs: [(Expression, [Statement])] = []
        var elseBody: [Statement]? = nil

        while check(.elif) {
            advance()
            let elifCond = try parseExpression()
            try expect(.do, "do")
            let elifBody = try parseBlock()
            elifs.append((elifCond, elifBody))
        }

        if matchToken(.else) {
            elseBody = try parseBlock()
        }

        try expect(.end, "end")
        return .ifStmt(condition, body, elifs, elseBody, loc)
    }

    private func parseForStmt() throws -> Statement {
        let loc = current.location
        try expect(.for, "for")
        let varName = try expectIdentifier()
        try expect(.in, "in")
        let iterable = try parseExpression()
        try expect(.do, "do")
        let body = try parseBlock()
        try expect(.end, "end")
        return .forStmt(varName, iterable, body, loc)
    }

    private func parseWhileStmt() throws -> Statement {
        let loc = current.location
        try expect(.while, "while")
        let condition = try parseExpression()
        try expect(.do, "do")
        let body = try parseBlock()
        try expect(.end, "end")
        return .whileStmt(condition, body, loc)
    }

    private func parseMatchStmt() throws -> Statement {
        let loc = current.location
        try expect(.match, "match")
        let expr = try parseExpression()
        skipNewlines()

        var cases: [MatchCase] = []
        while check(.case) {
            advance()
            skipNewlines()
            let pattern = try parsePattern()
            try expect(.arrow, "=>")
            // Match case body: either a single expression or multiple statements until next case/end
            var body: [Statement] = []
            skipNewlines()
            // Parse statements until we hit the next case or end
            while !check(.case) && !check(.end) && !isAtEnd {
                let stmt = try parseStatement()
                body.append(stmt)
                skipNewlines()
            }
            cases.append(MatchCase(pattern: pattern, body: body))
        }
        try expect(.end, "end")
        return .matchStmt(expr, cases, loc)
    }

    private func parsePattern() throws -> Pattern {
        let expr = try parsePrimary()

        // Check for range pattern
        if matchToken(.dotDot) {
            let end = try parsePrimary()
            return .range(expr, end)
        }

        // Variable capture: just an identifier
        if case .identifier(let name, let loc) = expr {
            // Could be a literal or variable capture — treat as variable capture
            // unless it's clearly a literal
            return .variable(name, loc)
        }

        return .literal(expr)
    }

    private func parseReturnStmt() throws -> Statement {
        let loc = current.location
        try expect(.return, "return")
        // Check if there's an expression to return
        if check(.newline) || check(.eof) || check(.end) {
            return .returnStmt(nil, loc)
        }
        let expr = try parseExpression()
        return .returnStmt(expr, loc)
    }

    private func parseStructDecl() throws -> Statement {
        let loc = current.location
        try expect(.struct, "struct")
        let name = try expectIdentifier()
        try expect(.do, "do")
        skipNewlines()

        var fields: [String] = []
        var methods: [Statement] = []

        while !check(.end) && !isAtEnd {
            skipNewlines()
            if check(.end) { break }

            if check(.fn) {
                let method = try parseFnDecl()
                methods.append(method)
            } else {
                // Field declaration — just an identifier
                let field = try expectIdentifier()
                fields.append(field)
            }
            skipNewlines()
        }
        try expect(.end, "end")
        return .structDecl(name, fields, methods, loc)
    }

    private func parseImportStmt() throws -> Statement {
        let loc = current.location
        try expect(.import, "import")
        let path = try expectString()
        var alias: String? = nil
        if matchToken(.as) {
            alias = try expectIdentifier()
        }
        return .importStmt(path, alias, loc)
    }

    private func parseTryCatch() throws -> Statement {
        let loc = current.location
        try expect(.try, "try")
        try expect(.do, "do")
        let tryBody = try parseBlock()
        try expect(.catch, "catch")
        let errorVar = try expectIdentifier()
        try expect(.do, "do")
        let catchBody = try parseBlock()
        try expect(.end, "end")
        return .tryCatch(tryBody, errorVar, catchBody, loc)
    }

    private func parseArgsBlock() throws -> Statement {
        let loc = current.location
        try expect(.args, "args")
        try expect(.do, "do")
        skipNewlines()

        var defs: [ArgDef] = []
        while !check(.end) && !isAtEnd {
            skipNewlines()
            if check(.end) { break }

            if check(.arg) {
                advance()
                let name = try expectIdentifier()
                try expect(.colon, ":")
                let type = try expectIdentifier()
                try expect(.comma, ",")
                let desc = try expectString()
                defs.append(.positional(name: name, type: type, description: desc))
            } else if check(.option) {
                advance()
                let name = try expectIdentifier()
                try expect(.colon, ":")
                let type = try expectIdentifier()
                try expect(.comma, ",")
                let desc = try expectString()
                var defaultValue: Expression? = nil
                if matchToken(.comma) {
                    // expect "default:"
                    let label = try expectIdentifier()
                    if label != "default" {
                        throw ParseError.unexpectedToken(current, expected: "default")
                    }
                    try expect(.colon, ":")
                    defaultValue = try parseExpression()
                }
                defs.append(.option(name: name, type: type, description: desc, defaultValue: defaultValue))
            } else if check(.flag) {
                advance()
                let name = try expectIdentifier()
                try expect(.colon, ":")
                let _ = try expectIdentifier() // "bool"
                try expect(.comma, ",")
                let desc = try expectString()
                var short: String? = nil
                if matchToken(.comma) {
                    let label = try expectIdentifier()
                    if label != "short" {
                        throw ParseError.unexpectedToken(current, expected: "short")
                    }
                    try expect(.colon, ":")
                    short = try expectString()
                }
                defs.append(.flag(name: name, description: desc, short: short))
            } else {
                throw ParseError.unexpectedToken(current, expected: "arg, option, or flag")
            }
            skipNewlines()
        }
        try expect(.end, "end")
        return .argsBlock(defs, loc)
    }

    // MARK: - Expression Parsing (Precedence Climbing)

    private func parseExpression() throws -> Expression {
        return try parseAssignment()
    }

    private func parseAssignment() throws -> Expression {
        let expr = try parsePipelineExpr()

        if check(.equal) && !check(.equalEqual) {
            let loc = current.location
            advance()
            let value = try parseAssignment()
            return .assign(expr, value, loc)
        }

        return expr
    }

    private func parsePipelineExpr() throws -> Expression {
        var expr = try parseOr()

        // Pipeline operator can span multiple lines:
        //   data
        //     |> filter(...)
        //     |> map(...)
        while true {
            let saved = position
            skipNewlines()
            if matchToken(.pipeline) {
                let loc = current.location
                let right = try parseOr()
                expr = .pipeline(expr, right, loc)
            } else {
                position = saved
                break
            }
        }

        return expr
    }

    private func parseOr() throws -> Expression {
        var expr = try parseAnd()
        while check(.or) {
            let loc = current.location
            advance()
            let right = try parseAnd()
            expr = .binary(expr, .or, right, loc)
        }
        return expr
    }

    private func parseAnd() throws -> Expression {
        var expr = try parseEquality()
        while check(.and) {
            let loc = current.location
            advance()
            let right = try parseEquality()
            expr = .binary(expr, .and, right, loc)
        }
        return expr
    }

    private func parseEquality() throws -> Expression {
        var expr = try parseComparison()
        while true {
            let loc = current.location
            if matchToken(.equalEqual) {
                let right = try parseComparison()
                expr = .binary(expr, .equal, right, loc)
            } else if matchToken(.bangEqual) {
                let right = try parseComparison()
                expr = .binary(expr, .notEqual, right, loc)
            } else {
                break
            }
        }
        return expr
    }

    private func parseComparison() throws -> Expression {
        var expr = try parseAddition()
        while true {
            let loc = current.location
            if matchToken(.less) {
                let right = try parseAddition()
                expr = .binary(expr, .less, right, loc)
            } else if matchToken(.lessEqual) {
                let right = try parseAddition()
                expr = .binary(expr, .lessEqual, right, loc)
            } else if matchToken(.greater) {
                let right = try parseAddition()
                expr = .binary(expr, .greater, right, loc)
            } else if matchToken(.greaterEqual) {
                let right = try parseAddition()
                expr = .binary(expr, .greaterEqual, right, loc)
            } else {
                break
            }
        }
        return expr
    }

    private func parseAddition() throws -> Expression {
        var expr = try parseMultiplication()
        while true {
            let loc = current.location
            if matchToken(.plus) {
                let right = try parseMultiplication()
                expr = .binary(expr, .add, right, loc)
            } else if matchToken(.minus) {
                let right = try parseMultiplication()
                expr = .binary(expr, .subtract, right, loc)
            } else {
                break
            }
        }
        return expr
    }

    private func parseMultiplication() throws -> Expression {
        var expr = try parseUnary()
        while true {
            let loc = current.location
            if matchToken(.star) {
                let right = try parseUnary()
                expr = .binary(expr, .multiply, right, loc)
            } else if matchToken(.slash) {
                let right = try parseUnary()
                expr = .binary(expr, .divide, right, loc)
            } else if matchToken(.percent) {
                let right = try parseUnary()
                expr = .binary(expr, .modulo, right, loc)
            } else {
                break
            }
        }
        return expr
    }

    private func parseUnary() throws -> Expression {
        if check(.minus) {
            let loc = current.location
            advance()
            let expr = try parseUnary()
            return .unary(.negate, expr, loc)
        }
        if check(.not) {
            let loc = current.location
            advance()
            let expr = try parseUnary()
            return .unary(.not, expr, loc)
        }
        return try parsePostfix()
    }

    private func parsePostfix() throws -> Expression {
        var expr = try parsePrimary()

        while true {
            if check(.leftParen) {
                expr = try parseCallExpr(callee: expr)
            } else if matchToken(.dot) {
                let name = try expectIdentifier()
                let loc = expr.location
                // Check for method call: expr.method(args)
                if check(.leftParen) {
                    let fieldExpr = Expression.fieldAccess(expr, name, loc)
                    expr = try parseCallExpr(callee: fieldExpr)
                } else {
                    expr = .fieldAccess(expr, name, loc)
                }
            } else if matchToken(.leftBracket) {
                let loc = expr.location
                let index = try parseExpression()
                try expect(.rightBracket, "]")
                expr = .index(expr, index, loc)
            } else {
                break
            }
        }

        return expr
    }

    private func parseCallExpr(callee: Expression) throws -> Expression {
        let loc = callee.location
        try expect(.leftParen, "(")
        var args: [CallArgument] = []

        if !check(.rightParen) {
            repeat {
                skipNewlines()
                // Check for named argument: name: value
                if case .identifier(let name) = current.type, peek()?.type == .colon {
                    advance() // identifier
                    advance() // colon
                    let value = try parseExpression()
                    args.append(CallArgument(label: name, value: value))
                } else {
                    let value = try parseExpression()
                    args.append(CallArgument(value: value))
                }
                skipNewlines()
            } while matchToken(.comma)
        }
        skipNewlines()
        try expect(.rightParen, ")")
        return .call(callee, args, loc)
    }

    private func parsePrimary() throws -> Expression {
        skipNewlines()
        let token = current

        switch token.type {
        case .intLiteral(let v):
            advance()
            return .intLiteral(v, token.location)

        case .floatLiteral(let v):
            advance()
            return .floatLiteral(v, token.location)

        case .stringLiteral(let v):
            advance()
            return .stringLiteral(v, token.location)

        case .interpolatedString(let parts):
            advance()
            // Parse expressions within interpolated parts
            var astParts: [InterpolationPart] = []
            for part in parts {
                switch part {
                case .literal(let s):
                    astParts.append(.literal(s))
                case .expression(let src):
                    let lexer = Lexer(source: src, fileName: fileName)
                    let tokens = try lexer.tokenize()
                    let parser = Parser(tokens: tokens, fileName: fileName)
                    let stmts = try parser.parse()
                    guard let first = stmts.first, case .expression(let expr) = first else {
                        throw ParseError.expectedExpression(token)
                    }
                    astParts.append(.expression(expr))
                }
            }
            return .interpolatedString(astParts, token.location)

        case .boolLiteral(let v):
            advance()
            return .boolLiteral(v, token.location)

        case .nilLiteral:
            advance()
            return .nilLiteral(token.location)

        case .identifier(let name):
            advance()
            return .identifier(name, token.location)

        case .self:
            advance()
            return .selfExpr(token.location)

        case .leftParen:
            advance()
            let expr = try parseExpression()
            try expect(.rightParen, ")")
            return expr

        case .leftBracket:
            return try parseListLiteral()

        case .leftBrace:
            return try parseMapLiteral()

        case .fn:
            return try parseLambda()

        case .minus:
            // Negative number
            let loc = token.location
            advance()
            let expr = try parsePrimary()
            return .unary(.negate, expr, loc)

        case .not:
            let loc = token.location
            advance()
            let expr = try parseUnary()
            return .unary(.not, expr, loc)

        default:
            throw ParseError.expectedExpression(token)
        }
    }

    private func parseListLiteral() throws -> Expression {
        let loc = current.location
        try expect(.leftBracket, "[")
        var elements: [Expression] = []
        if !check(.rightBracket) {
            repeat {
                skipNewlines()
                let elem = try parseExpression()
                elements.append(elem)
                skipNewlines()
            } while matchToken(.comma)
        }
        skipNewlines()
        try expect(.rightBracket, "]")
        return .listLiteral(elements, loc)
    }

    private func parseMapLiteral() throws -> Expression {
        let loc = current.location
        try expect(.leftBrace, "{")
        var pairs: [(String, Expression)] = []
        if !check(.rightBrace) {
            repeat {
                skipNewlines()
                let key = try expectIdentifier()
                try expect(.colon, ":")
                let value = try parseExpression()
                pairs.append((key, value))
                skipNewlines()
            } while matchToken(.comma)
        }
        skipNewlines()
        try expect(.rightBrace, "}")
        return .mapLiteral(pairs, loc)
    }

    private func parseLambda() throws -> Expression {
        let loc = current.location
        try expect(.fn, "fn")
        let params = try parseParamList()
        if matchToken(.arrow) {
            let expr = try parseExpression()
            return .lambda(params, [.expression(expr)], true, loc)
        }
        try expect(.do, "do")
        let body = try parseBlock()
        try expect(.end, "end")
        return .lambda(params, body, false, loc)
    }

    // MARK: - Block Parsing

    private func parseBlock() throws -> [Statement] {
        skipNewlines()
        var statements: [Statement] = []
        while !check(.end) && !check(.else) && !check(.elif) && !check(.catch) && !check(.case) && !check(.eof) {
            let stmt = try parseStatement()
            statements.append(stmt)
            skipNewlines()
        }
        return statements
    }

    // MARK: - Token Helpers

    private var current: Token {
        guard position < tokens.count else {
            return Token(type: .eof, location: SourceLocation(line: 0, column: 0))
        }
        return tokens[position]
    }

    private var isAtEnd: Bool {
        current.type == .eof
    }

    @discardableResult
    private func advance() -> Token {
        let tok = current
        if position < tokens.count {
            position += 1
        }
        return tok
    }

    private func check(_ type: TokenType) -> Bool {
        return current.type == type
    }

    private func matchToken(_ type: TokenType) -> Bool {
        if check(type) {
            advance()
            return true
        }
        return false
    }

    private func peek() -> Token? {
        guard position + 1 < tokens.count else { return nil }
        return tokens[position + 1]
    }

    @discardableResult
    private func expect(_ type: TokenType, _ description: String) throws -> Token {
        if check(type) {
            return advance()
        }
        if isAtEnd {
            throw ParseError.unexpectedEOF(expected: description)
        }
        throw ParseError.unexpectedToken(current, expected: description)
    }

    private func expectIdentifier() throws -> String {
        if case .identifier(let name) = current.type {
            advance()
            return name
        }
        if isAtEnd {
            throw ParseError.unexpectedEOF(expected: "identifier")
        }
        throw ParseError.unexpectedToken(current, expected: "identifier")
    }

    private func expectString() throws -> String {
        if case .stringLiteral(let value) = current.type {
            advance()
            return value
        }
        if isAtEnd {
            throw ParseError.unexpectedEOF(expected: "string")
        }
        throw ParseError.unexpectedToken(current, expected: "string")
    }

    private func skipNewlines() {
        while check(.newline) {
            advance()
        }
    }
}
