import XCTest
@testable import ClaudineCore

final class InterpreterTests: XCTestCase {

    private func interpret(_ source: String) throws -> Interpreter {
        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let stmts = try parser.parse()
        let interpreter = Interpreter()
        try interpreter.execute(stmts)
        return interpreter
    }

    private func eval(_ source: String) throws -> Value {
        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let stmts = try parser.parse()
        let interpreter = Interpreter()
        guard stmts.count == 1, case .expression(let expr) = stmts[0] else {
            try interpreter.execute(stmts)
            return .nil
        }
        return try interpreter.evaluate(expr, env: interpreter.globalEnv)
    }

    // MARK: - Arithmetic

    func testIntArithmetic() throws {
        XCTAssertEqual(try eval("2 + 3"), .int(5))
        XCTAssertEqual(try eval("10 - 3"), .int(7))
        XCTAssertEqual(try eval("4 * 5"), .int(20))
        XCTAssertEqual(try eval("10 / 3"), .int(3))
        XCTAssertEqual(try eval("10 % 3"), .int(1))
    }

    func testFloatArithmetic() throws {
        XCTAssertEqual(try eval("2.5 + 1.5"), .float(4.0))
        XCTAssertEqual(try eval("3.0 * 2.0"), .float(6.0))
    }

    func testMixedArithmetic() throws {
        XCTAssertEqual(try eval("2 + 3.0"), .float(5.0))
        XCTAssertEqual(try eval("3.0 * 2"), .float(6.0))
    }

    func testPrecedence() throws {
        XCTAssertEqual(try eval("2 + 3 * 4"), .int(14))
        XCTAssertEqual(try eval("(2 + 3) * 4"), .int(20))
    }

    func testNegation() throws {
        XCTAssertEqual(try eval("-5"), .int(-5))
        XCTAssertEqual(try eval("-3.14"), .float(-3.14))
    }

    // MARK: - Strings

    func testStringConcatenation() throws {
        XCTAssertEqual(try eval("\"hello\" + \" \" + \"world\""), .string("hello world"))
    }

    func testStringMultiply() throws {
        XCTAssertEqual(try eval("\"ha\" * 3"), .string("hahaha"))
    }

    func testStringInterpolation() throws {
        let interp = try interpret("let name = \"World\"")
        let lexer = Lexer(source: "\"Hello, {name}!\"")
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let stmts = try parser.parse()
        if case .expression(let expr) = stmts[0] {
            let result = try interp.evaluate(expr, env: interp.globalEnv)
            XCTAssertEqual(result, .string("Hello, World!"))
        }
    }

    // MARK: - Comparisons

    func testComparisons() throws {
        XCTAssertEqual(try eval("1 == 1"), .bool(true))
        XCTAssertEqual(try eval("1 != 2"), .bool(true))
        XCTAssertEqual(try eval("1 < 2"), .bool(true))
        XCTAssertEqual(try eval("2 <= 2"), .bool(true))
        XCTAssertEqual(try eval("3 > 2"), .bool(true))
        XCTAssertEqual(try eval("2 >= 3"), .bool(false))
    }

    func testLogical() throws {
        XCTAssertEqual(try eval("true and true"), .bool(true))
        XCTAssertEqual(try eval("true and false"), .bool(false))
        XCTAssertEqual(try eval("false or true"), .bool(true))
        XCTAssertEqual(try eval("not true"), .bool(false))
    }

    // MARK: - Variables

    func testLetBinding() throws {
        let interp = try interpret("let x = 42")
        XCTAssertEqual(try interp.globalEnv.get("x"), .int(42))
    }

    func testVarMutation() throws {
        let interp = try interpret("""
        var x = 1
        x = 2
        """)
        XCTAssertEqual(try interp.globalEnv.get("x"), .int(2))
    }

    func testLetImmutability() throws {
        XCTAssertThrowsError(try interpret("""
        let x = 1
        x = 2
        """)) { error in
            XCTAssertTrue(error is RuntimeError)
        }
    }

    // MARK: - Functions

    func testFunctionCall() throws {
        let interp = try interpret("""
        fn add(a, b) do
          return a + b
        end
        let result = add(3, 4)
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .int(7))
    }

    func testShorthandFunction() throws {
        let interp = try interpret("""
        fn double(x) => x * 2
        let result = double(5)
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .int(10))
    }

    func testClosure() throws {
        let interp = try interpret("""
        fn make_adder(n) do
          return fn(x) => x + n
        end
        let add5 = make_adder(5)
        let result = add5(10)
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .int(15))
    }

    func testRecursion() throws {
        let interp = try interpret("""
        fn factorial(n) do
          if n <= 1 do
            return 1
          end
          return n * factorial(n - 1)
        end
        let result = factorial(5)
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .int(120))
    }

    // MARK: - Control Flow

    func testIfElse() throws {
        let interp = try interpret("""
        var result = ""
        let x = 10
        if x > 5 do
          result = "big"
        else
          result = "small"
        end
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .string("big"))
    }

    func testElif() throws {
        let interp = try interpret("""
        var result = ""
        let x = 50
        if x > 100 do
          result = "big"
        elif x > 10 do
          result = "medium"
        else
          result = "small"
        end
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .string("medium"))
    }

    func testForLoop() throws {
        let interp = try interpret("""
        var sum = 0
        for i in [1, 2, 3, 4, 5] do
          sum = sum + i
        end
        """)
        XCTAssertEqual(try interp.globalEnv.get("sum"), .int(15))
    }

    func testWhileLoop() throws {
        let interp = try interpret("""
        var count = 0
        while count < 5 do
          count = count + 1
        end
        """)
        XCTAssertEqual(try interp.globalEnv.get("count"), .int(5))
    }

    func testBreak() throws {
        let interp = try interpret("""
        var count = 0
        while true do
          if count == 3 do
            break
          end
          count = count + 1
        end
        """)
        XCTAssertEqual(try interp.globalEnv.get("count"), .int(3))
    }

    func testContinue() throws {
        let interp = try interpret("""
        var sum = 0
        for i in [1, 2, 3, 4, 5] do
          if i == 3 do
            continue
          end
          sum = sum + i
        end
        """)
        XCTAssertEqual(try interp.globalEnv.get("sum"), .int(12))
    }

    // MARK: - Lists

    func testListCreation() throws {
        XCTAssertEqual(try eval("[1, 2, 3]"), .list([.int(1), .int(2), .int(3)]))
    }

    func testListIndexing() throws {
        let interp = try interpret("let x = [10, 20, 30]")
        let lexer = Lexer(source: "x[1]")
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let stmts = try parser.parse()
        if case .expression(let expr) = stmts[0] {
            XCTAssertEqual(try interp.evaluate(expr, env: interp.globalEnv), .int(20))
        }
    }

    func testListNegativeIndex() throws {
        let interp = try interpret("let x = [10, 20, 30]")
        let lexer = Lexer(source: "x[-1]")
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let stmts = try parser.parse()
        if case .expression(let expr) = stmts[0] {
            XCTAssertEqual(try interp.evaluate(expr, env: interp.globalEnv), .int(30))
        }
    }

    // MARK: - Maps

    func testMapCreation() throws {
        let val = try eval("{name: \"test\", value: 42}")
        if case .map(let m) = val {
            XCTAssertEqual(m["name"], .string("test"))
            XCTAssertEqual(m["value"], .int(42))
        } else { XCTFail("Expected map") }
    }

    func testMapAccess() throws {
        let interp = try interpret("let m = {name: \"test\"}")
        let lexer = Lexer(source: "m[\"name\"]")
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let stmts = try parser.parse()
        if case .expression(let expr) = stmts[0] {
            XCTAssertEqual(try interp.evaluate(expr, env: interp.globalEnv), .string("test"))
        }
    }

    // MARK: - Pattern Matching

    func testMatchLiteral() throws {
        let interp = try interpret("""
        var result = ""
        let x = 1
        match x
          case 0 => result = "zero"
          case 1 => result = "one"
          case n => result = "other"
        end
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .string("one"))
    }

    func testMatchVariable() throws {
        let interp = try interpret("""
        var result = ""
        let x = 42
        match x
          case 0 => result = "zero"
          case n => result = "other"
        end
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .string("other"))
    }

    // MARK: - Structs

    func testStructCreation() throws {
        let interp = try interpret("""
        struct Point do
          x
          y
        end
        let p = Point(x: 10, y: 20)
        """)
        let p = try interp.globalEnv.get("p")
        if case .structInstance(let inst) = p {
            XCTAssertEqual(inst.fields["x"], .int(10))
            XCTAssertEqual(inst.fields["y"], .int(20))
        } else { XCTFail("Expected struct instance") }
    }

    func testStructMethod() throws {
        let interp = try interpret("""
        struct Counter do
          count

          fn increment() do
            return self.count + 1
          end
        end
        let c = Counter(count: 5)
        let result = c.increment()
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .int(6))
    }

    // MARK: - Pipeline

    func testPipeline() throws {
        let interp = try interpret("""
        fn double(x) => x * 2
        fn add1(x) => x + 1
        let result = 5 |> double() |> add1()
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .int(11))
    }

    // MARK: - Try/Catch

    func testTryCatch() throws {
        let interp = try interpret("""
        var result = ""
        try do
          let x = 1 / 0
        catch error do
          result = "caught"
        end
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .string("caught"))
    }

    // MARK: - Built-in Functions

    func testLength() throws {
        XCTAssertEqual(try eval("length(\"hello\")"), .int(5))
        XCTAssertEqual(try eval("length([1, 2, 3])"), .int(3))
    }

    func testTypeOf() throws {
        XCTAssertEqual(try eval("type_of(42)"), .string("int"))
        XCTAssertEqual(try eval("type_of(\"hello\")"), .string("string"))
        XCTAssertEqual(try eval("type_of(true)"), .string("bool"))
        XCTAssertEqual(try eval("type_of(nil)"), .string("nil"))
        XCTAssertEqual(try eval("type_of([1, 2])"), .string("list"))
    }

    func testToString() throws {
        XCTAssertEqual(try eval("to_string(42)"), .string("42"))
        XCTAssertEqual(try eval("to_string(true)"), .string("true"))
    }

    func testToInt() throws {
        XCTAssertEqual(try eval("to_int(3.14)"), .int(3))
        XCTAssertEqual(try eval("to_int(\"42\")"), .int(42))
    }

    func testToFloat() throws {
        XCTAssertEqual(try eval("to_float(42)"), .float(42.0))
        XCTAssertEqual(try eval("to_float(\"3.14\")"), .float(3.14))
    }

    // MARK: - String Functions

    func testSplit() throws {
        XCTAssertEqual(try eval("split(\"a,b,c\", \",\")"), .list([.string("a"), .string("b"), .string("c")]))
    }

    func testJoin() throws {
        XCTAssertEqual(try eval("join([\"a\", \"b\", \"c\"], \",\")"), .string("a,b,c"))
    }

    func testTrim() throws {
        XCTAssertEqual(try eval("trim(\"  hello  \")"), .string("hello"))
    }

    func testReplace() throws {
        XCTAssertEqual(try eval("replace(\"hello world\", \"world\", \"Claudine\")"), .string("hello Claudine"))
    }

    func testContains() throws {
        XCTAssertEqual(try eval("contains(\"hello world\", \"world\")"), .bool(true))
        XCTAssertEqual(try eval("contains(\"hello world\", \"xyz\")"), .bool(false))
    }

    func testStartsWith() throws {
        XCTAssertEqual(try eval("starts_with(\"hello\", \"hel\")"), .bool(true))
    }

    func testEndsWith() throws {
        XCTAssertEqual(try eval("ends_with(\"hello\", \"llo\")"), .bool(true))
    }

    func testUpper() throws {
        XCTAssertEqual(try eval("upper(\"hello\")"), .string("HELLO"))
    }

    func testLower() throws {
        XCTAssertEqual(try eval("lower(\"HELLO\")"), .string("hello"))
    }

    // MARK: - List Functions

    func testPush() throws {
        XCTAssertEqual(try eval("push([1, 2], 3)"), .list([.int(1), .int(2), .int(3)]))
    }

    func testReverse() throws {
        XCTAssertEqual(try eval("reverse([1, 2, 3])"), .list([.int(3), .int(2), .int(1)]))
    }

    func testSort() throws {
        XCTAssertEqual(try eval("sort([3, 1, 2])"), .list([.int(1), .int(2), .int(3)]))
    }

    func testFlatten() throws {
        XCTAssertEqual(try eval("flatten([[1, 2], [3, 4]])"), .list([.int(1), .int(2), .int(3), .int(4)]))
    }

    func testSum() throws {
        XCTAssertEqual(try eval("sum([1, 2, 3, 4, 5])"), .int(15))
    }

    // MARK: - Map Functions

    func testKeys() throws {
        let interp = try interpret("let m = {a: 1, b: 2}")
        let lexer = Lexer(source: "keys(m)")
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let stmts = try parser.parse()
        if case .expression(let expr) = stmts[0] {
            let result = try interp.evaluate(expr, env: interp.globalEnv)
            if case .list(let items) = result {
                XCTAssertTrue(items.contains(.string("a")))
                XCTAssertTrue(items.contains(.string("b")))
            } else { XCTFail("Expected list") }
        }
    }

    func testHasKey() throws {
        let interp = try interpret("let m = {a: 1, b: 2}")
        let lexer = Lexer(source: "has_key(m, \"a\")")
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let stmts = try parser.parse()
        if case .expression(let expr) = stmts[0] {
            XCTAssertEqual(try interp.evaluate(expr, env: interp.globalEnv), .bool(true))
        }
    }

    // MARK: - Math Functions

    func testAbs() throws {
        XCTAssertEqual(try eval("abs(-5)"), .int(5))
        XCTAssertEqual(try eval("abs(5)"), .int(5))
    }

    func testMinMax() throws {
        XCTAssertEqual(try eval("min(3, 1, 2)"), .int(1))
        XCTAssertEqual(try eval("max(3, 1, 2)"), .int(3))
    }

    func testFloorCeilRound() throws {
        XCTAssertEqual(try eval("floor(3.7)"), .int(3))
        XCTAssertEqual(try eval("ceil(3.2)"), .int(4))
        XCTAssertEqual(try eval("round(3.5)"), .int(4))
    }

    func testSqrt() throws {
        XCTAssertEqual(try eval("sqrt(16)"), .float(4.0))
    }

    // MARK: - Division by Zero

    func testDivisionByZero() throws {
        XCTAssertThrowsError(try eval("1 / 0")) { error in
            XCTAssertTrue(error is RuntimeError)
        }
    }

    // MARK: - Range

    func testRange() throws {
        XCTAssertEqual(try eval("range(5)"), .list([.int(0), .int(1), .int(2), .int(3), .int(4)]))
        XCTAssertEqual(try eval("range(2, 5)"), .list([.int(2), .int(3), .int(4)]))
    }

    // MARK: - For with String

    func testForOverString() throws {
        let interp = try interpret("""
        var result = []
        for ch in "abc" do
          result = push(result, ch)
        end
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .list([.string("a"), .string("b"), .string("c")]))
    }

    // MARK: - Higher-order Functions

    func testMapFilter() throws {
        let interp = try interpret("""
        let nums = [1, 2, 3, 4, 5]
        let doubled = map(nums, fn(x) => x * 2)
        let evens = filter(nums, fn(x) => x % 2 == 0)
        """)
        XCTAssertEqual(try interp.globalEnv.get("doubled"), .list([.int(2), .int(4), .int(6), .int(8), .int(10)]))
        XCTAssertEqual(try interp.globalEnv.get("evens"), .list([.int(2), .int(4)]))
    }

    func testReduce() throws {
        let interp = try interpret("""
        let result = reduce([1, 2, 3, 4, 5], 0, fn(acc, x) => acc + x)
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .int(15))
    }
}
