import XCTest
@testable import ClaudineCore

final class LexerTests: XCTestCase {

    private func tokenize(_ source: String) throws -> [Token] {
        let lexer = Lexer(source: source)
        return try lexer.tokenize()
    }

    private func tokenTypes(_ source: String) throws -> [TokenType] {
        return try tokenize(source).map(\.type)
    }

    // MARK: - Basic Tokens

    func testEmptySource() throws {
        let types = try tokenTypes("")
        XCTAssertEqual(types, [.eof])
    }

    func testSingleInteger() throws {
        let types = try tokenTypes("42")
        XCTAssertEqual(types, [.intLiteral(42), .eof])
    }

    func testFloat() throws {
        let types = try tokenTypes("3.14")
        XCTAssertEqual(types, [.floatLiteral(3.14), .eof])
    }

    func testSimpleString() throws {
        let types = try tokenTypes("\"hello\"")
        XCTAssertEqual(types, [.stringLiteral("hello"), .eof])
    }

    func testBooleans() throws {
        let types = try tokenTypes("true false")
        XCTAssertEqual(types, [.boolLiteral(true), .boolLiteral(false), .eof])
    }

    func testNil() throws {
        let types = try tokenTypes("nil")
        XCTAssertEqual(types, [.nilLiteral, .eof])
    }

    // MARK: - Identifiers and Keywords

    func testIdentifier() throws {
        let types = try tokenTypes("foo bar_baz")
        XCTAssertEqual(types, [.identifier("foo"), .identifier("bar_baz"), .eof])
    }

    func testKeywords() throws {
        let types = try tokenTypes("let var fn do end if else elif")
        XCTAssertEqual(types, [
            .let, .var, .fn, .do, .end, .if, .else, .elif, .eof
        ])
    }

    func testMoreKeywords() throws {
        let types = try tokenTypes("for in while match case return struct import as try catch")
        XCTAssertEqual(types, [
            .for, .in, .while, .match, .case, .return, .struct, .import, .as, .try, .catch, .eof
        ])
    }

    func testLogicalKeywords() throws {
        let types = try tokenTypes("and or not")
        XCTAssertEqual(types, [.and, .or, .not, .eof])
    }

    // MARK: - Operators

    func testArithmeticOperators() throws {
        let types = try tokenTypes("+ - * / %")
        XCTAssertEqual(types, [.plus, .minus, .star, .slash, .percent, .eof])
    }

    func testComparisonOperators() throws {
        let types = try tokenTypes("== != < <= > >=")
        XCTAssertEqual(types, [.equalEqual, .bangEqual, .less, .lessEqual, .greater, .greaterEqual, .eof])
    }

    func testAssignmentAndArrow() throws {
        let types = try tokenTypes("= =>")
        XCTAssertEqual(types, [.equal, .arrow, .eof])
    }

    func testPipeline() throws {
        let types = try tokenTypes("|>")
        XCTAssertEqual(types, [.pipeline, .eof])
    }

    func testDotDot() throws {
        let types = try tokenTypes("..")
        XCTAssertEqual(types, [.dotDot, .eof])
    }

    // MARK: - Delimiters

    func testDelimiters() throws {
        let types = try tokenTypes("( ) [ ] { } , . :")
        XCTAssertEqual(types, [
            .leftParen, .rightParen, .leftBracket, .rightBracket,
            .leftBrace, .rightBrace, .comma, .dot, .colon, .eof
        ])
    }

    // MARK: - Newlines

    func testNewlines() throws {
        let types = try tokenTypes("a\nb")
        XCTAssertEqual(types, [.identifier("a"), .newline, .identifier("b"), .eof])
    }

    // MARK: - Comments

    func testSingleLineComment() throws {
        let types = try tokenTypes("a # this is a comment\nb")
        XCTAssertEqual(types, [.identifier("a"), .newline, .identifier("b"), .eof])
    }

    func testMultiLineComment() throws {
        let types = try tokenTypes("a #= multi\nline =#  b")
        XCTAssertEqual(types, [.identifier("a"), .identifier("b"), .eof])
    }

    // MARK: - String Interpolation

    func testStringInterpolation() throws {
        let tokens = try tokenize("\"hello {name}\"")
        XCTAssertEqual(tokens.count, 2) // interpolated string + eof
        if case .interpolatedString(let parts) = tokens[0].type {
            XCTAssertEqual(parts.count, 2)
            XCTAssertEqual(parts[0], .literal("hello "))
            XCTAssertEqual(parts[1], .expression("name"))
        } else {
            XCTFail("Expected interpolated string")
        }
    }

    func testEscapedBraceInString() throws {
        let types = try tokenTypes("\"hello \\{world}\"")
        XCTAssertEqual(types, [.stringLiteral("hello {world}"), .eof])
    }

    func testEscapeSequences() throws {
        let types = try tokenTypes("\"line1\\nline2\\t\"")
        XCTAssertEqual(types, [.stringLiteral("line1\nline2\t"), .eof])
    }

    // MARK: - Complex Expressions

    func testLetDeclaration() throws {
        let types = try tokenTypes("let x = 42")
        XCTAssertEqual(types, [.let, .identifier("x"), .equal, .intLiteral(42), .eof])
    }

    func testFunctionDecl() throws {
        let types = try tokenTypes("fn greet(name) do\n  print(name)\nend")
        XCTAssertEqual(types, [
            .fn, .identifier("greet"), .leftParen, .identifier("name"), .rightParen, .do,
            .newline, .identifier("print"), .leftParen, .identifier("name"), .rightParen,
            .newline, .end, .eof
        ])
    }

    func testPipelineExpression() throws {
        let types = try tokenTypes("data |> map(fn(x) => x * 2)")
        XCTAssertEqual(types, [
            .identifier("data"), .pipeline, .identifier("map"), .leftParen,
            .fn, .leftParen, .identifier("x"), .rightParen, .arrow,
            .identifier("x"), .star, .intLiteral(2), .rightParen, .eof
        ])
    }

    // MARK: - Error Cases

    func testUnterminatedString() {
        XCTAssertThrowsError(try tokenize("\"hello")) { error in
            XCTAssertTrue(error is LexerError)
        }
    }

    func testUnexpectedCharacter() {
        XCTAssertThrowsError(try tokenize("@")) { error in
            XCTAssertTrue(error is LexerError)
        }
    }

    // MARK: - Number Underscores

    func testNumberWithUnderscores() throws {
        let types = try tokenTypes("1_000_000")
        XCTAssertEqual(types, [.intLiteral(1000000), .eof])
    }

    // MARK: - Source Location

    func testSourceLocation() throws {
        let tokens = try tokenize("let x = 42\nlet y = 10")
        XCTAssertEqual(tokens[0].location.line, 1)
        XCTAssertEqual(tokens[0].location.column, 1)
        // "let" on second line
        let secondLet = tokens.first(where: { $0.location.line == 2 && $0.type == .let })
        XCTAssertNotNil(secondLet)
    }
}
