import XCTest
@testable import ClaudineCore

final class ParserTests: XCTestCase {

    private func parse(_ source: String) throws -> [Statement] {
        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        return try parser.parse()
    }

    // MARK: - Variable Declarations

    func testLetDeclaration() throws {
        let stmts = try parse("let x = 42")
        XCTAssertEqual(stmts.count, 1)
        if case .letDecl(let name, let expr, _) = stmts[0] {
            XCTAssertEqual(name, "x")
            if case .intLiteral(let v, _) = expr {
                XCTAssertEqual(v, 42)
            } else { XCTFail("Expected int literal") }
        } else { XCTFail("Expected let declaration") }
    }

    func testVarDeclaration() throws {
        let stmts = try parse("var count = 0")
        XCTAssertEqual(stmts.count, 1)
        if case .varDecl(let name, _, _) = stmts[0] {
            XCTAssertEqual(name, "count")
        } else { XCTFail("Expected var declaration") }
    }

    // MARK: - Expressions

    func testBinaryExpression() throws {
        let stmts = try parse("1 + 2 * 3")
        XCTAssertEqual(stmts.count, 1)
        if case .expression(let expr) = stmts[0] {
            // Should be: 1 + (2 * 3) due to precedence
            if case .binary(let left, let op, let right, _) = expr {
                XCTAssertEqual(op, .add)
                if case .intLiteral(1, _) = left {} else { XCTFail("Expected 1") }
                if case .binary(_, .multiply, _, _) = right {} else { XCTFail("Expected multiply") }
            } else { XCTFail("Expected binary expression") }
        } else { XCTFail("Expected expression statement") }
    }

    func testComparisonExpression() throws {
        let stmts = try parse("x >= 18")
        XCTAssertEqual(stmts.count, 1)
        if case .expression(.binary(_, .greaterEqual, _, _)) = stmts[0] {
        } else { XCTFail("Expected >= comparison") }
    }

    func testLogicalExpression() throws {
        let stmts = try parse("a and b or c")
        XCTAssertEqual(stmts.count, 1)
        if case .expression(.binary(_, .or, _, _)) = stmts[0] {
            // 'or' has lower precedence, so it's the top-level op
        } else { XCTFail("Expected logical expression") }
    }

    func testUnaryExpression() throws {
        let stmts = try parse("not true")
        XCTAssertEqual(stmts.count, 1)
        if case .expression(.unary(.not, _, _)) = stmts[0] {
        } else { XCTFail("Expected not expression") }
    }

    func testNegation() throws {
        let stmts = try parse("-42")
        XCTAssertEqual(stmts.count, 1)
        if case .expression(.unary(.negate, .intLiteral(42, _), _)) = stmts[0] {
        } else { XCTFail("Expected negation") }
    }

    // MARK: - Function Declaration

    func testFnDeclDo() throws {
        let stmts = try parse("fn greet(name) do\n  println(name)\nend")
        XCTAssertEqual(stmts.count, 1)
        if case .fnDecl(let name, let params, let body, let isShort, _) = stmts[0] {
            XCTAssertEqual(name, "greet")
            XCTAssertEqual(params.count, 1)
            XCTAssertEqual(params[0].name, "name")
            XCTAssertFalse(isShort)
            XCTAssertEqual(body.count, 1)
        } else { XCTFail("Expected fn decl") }
    }

    func testFnDeclShorthand() throws {
        let stmts = try parse("fn double(x) => x * 2")
        XCTAssertEqual(stmts.count, 1)
        if case .fnDecl(let name, _, _, let isShort, _) = stmts[0] {
            XCTAssertEqual(name, "double")
            XCTAssertTrue(isShort)
        } else { XCTFail("Expected fn decl") }
    }

    // MARK: - If Statement

    func testIfElse() throws {
        let stmts = try parse("""
        if x > 0 do
          println("positive")
        else
          println("non-positive")
        end
        """)
        XCTAssertEqual(stmts.count, 1)
        if case .ifStmt(_, let body, let elifs, let elseBody, _) = stmts[0] {
            XCTAssertEqual(body.count, 1)
            XCTAssertEqual(elifs.count, 0)
            XCTAssertNotNil(elseBody)
            XCTAssertEqual(elseBody?.count, 1)
        } else { XCTFail("Expected if statement") }
    }

    func testIfElif() throws {
        let stmts = try parse("""
        if x > 100 do
          println("big")
        elif x > 10 do
          println("medium")
        else
          println("small")
        end
        """)
        XCTAssertEqual(stmts.count, 1)
        if case .ifStmt(_, _, let elifs, let elseBody, _) = stmts[0] {
            XCTAssertEqual(elifs.count, 1)
            XCTAssertNotNil(elseBody)
        } else { XCTFail("Expected if statement with elif") }
    }

    // MARK: - Loops

    func testForLoop() throws {
        let stmts = try parse("""
        for item in items do
          println(item)
        end
        """)
        XCTAssertEqual(stmts.count, 1)
        if case .forStmt(let varName, _, let body, _) = stmts[0] {
            XCTAssertEqual(varName, "item")
            XCTAssertEqual(body.count, 1)
        } else { XCTFail("Expected for statement") }
    }

    func testWhileLoop() throws {
        let stmts = try parse("""
        while x > 0 do
          x = x - 1
        end
        """)
        XCTAssertEqual(stmts.count, 1)
        if case .whileStmt(_, let body, _) = stmts[0] {
            XCTAssertEqual(body.count, 1)
        } else { XCTFail("Expected while statement") }
    }

    // MARK: - Match

    func testMatchStatement() throws {
        let stmts = try parse("""
        match value
          case 0 => println("zero")
          case n => println(n)
        end
        """)
        XCTAssertEqual(stmts.count, 1)
        if case .matchStmt(_, let cases, _) = stmts[0] {
            XCTAssertEqual(cases.count, 2)
        } else { XCTFail("Expected match statement") }
    }

    // MARK: - Collections

    func testListLiteral() throws {
        let stmts = try parse("[1, 2, 3]")
        XCTAssertEqual(stmts.count, 1)
        if case .expression(.listLiteral(let elems, _)) = stmts[0] {
            XCTAssertEqual(elems.count, 3)
        } else { XCTFail("Expected list literal") }
    }

    func testMapLiteral() throws {
        let stmts = try parse("{name: \"app\", version: \"1.0\"}")
        XCTAssertEqual(stmts.count, 1)
        if case .expression(.mapLiteral(let pairs, _)) = stmts[0] {
            XCTAssertEqual(pairs.count, 2)
            XCTAssertEqual(pairs[0].0, "name")
        } else { XCTFail("Expected map literal") }
    }

    // MARK: - Pipeline

    func testPipelineExpression() throws {
        let stmts = try parse("x |> double()")
        XCTAssertEqual(stmts.count, 1)
        if case .expression(.pipeline(_, _, _)) = stmts[0] {
        } else { XCTFail("Expected pipeline expression") }
    }

    // MARK: - Struct

    func testStructDecl() throws {
        let stmts = try parse("""
        struct Point do
          x
          y
          fn distance(other) do
            return 0
          end
        end
        """)
        XCTAssertEqual(stmts.count, 1)
        if case .structDecl(let name, let fields, let methods, _) = stmts[0] {
            XCTAssertEqual(name, "Point")
            XCTAssertEqual(fields, ["x", "y"])
            XCTAssertEqual(methods.count, 1)
        } else { XCTFail("Expected struct declaration") }
    }

    // MARK: - Try/Catch

    func testTryCatch() throws {
        let stmts = try parse("""
        try do
          let x = 1 / 0
        catch error do
          println(error)
        end
        """)
        XCTAssertEqual(stmts.count, 1)
        if case .tryCatch(let tryBody, let errorVar, let catchBody, _) = stmts[0] {
            XCTAssertEqual(tryBody.count, 1)
            XCTAssertEqual(errorVar, "error")
            XCTAssertEqual(catchBody.count, 1)
        } else { XCTFail("Expected try/catch") }
    }

    // MARK: - Import

    func testImport() throws {
        let stmts = try parse("import \"utils.cln\"")
        XCTAssertEqual(stmts.count, 1)
        if case .importStmt(let path, let alias, _) = stmts[0] {
            XCTAssertEqual(path, "utils.cln")
            XCTAssertNil(alias)
        } else { XCTFail("Expected import statement") }
    }

    func testImportAs() throws {
        let stmts = try parse("import \"lib/helpers.cln\" as helpers")
        XCTAssertEqual(stmts.count, 1)
        if case .importStmt(let path, let alias, _) = stmts[0] {
            XCTAssertEqual(path, "lib/helpers.cln")
            XCTAssertEqual(alias, "helpers")
        } else { XCTFail("Expected import as statement") }
    }

    // MARK: - Lambda

    func testLambda() throws {
        let stmts = try parse("let sq = fn(x) => x * x")
        XCTAssertEqual(stmts.count, 1)
        if case .letDecl(_, .lambda(let params, _, let isShort, _), _) = stmts[0] {
            XCTAssertEqual(params.count, 1)
            XCTAssertTrue(isShort)
        } else { XCTFail("Expected lambda") }
    }

    // MARK: - Call with Named Args

    func testNamedArgs() throws {
        let stmts = try parse("ask(\"hello\", model: \"sonnet\")")
        XCTAssertEqual(stmts.count, 1)
        if case .expression(.call(_, let args, _)) = stmts[0] {
            XCTAssertEqual(args.count, 2)
            XCTAssertNil(args[0].label)
            XCTAssertEqual(args[1].label, "model")
        } else { XCTFail("Expected call with named args") }
    }

    // MARK: - Error Cases

    func testMissingEnd() {
        XCTAssertThrowsError(try parse("if true do\n  println(1)")) { error in
            XCTAssertTrue(error is ParseError)
        }
    }
}
