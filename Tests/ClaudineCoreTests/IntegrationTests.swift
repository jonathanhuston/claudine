import XCTest
@testable import ClaudineCore

final class IntegrationTests: XCTestCase {

    private func run(_ source: String) throws -> Interpreter {
        let lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens)
        let stmts = try parser.parse()
        let interpreter = Interpreter()
        try interpreter.execute(stmts)
        return interpreter
    }

    // MARK: - FizzBuzz

    func testFizzBuzz() throws {
        let interp = try run("""
        var result = []
        for i in range(1, 16) do
          if i % 15 == 0 do
            result = push(result, "FizzBuzz")
          elif i % 3 == 0 do
            result = push(result, "Fizz")
          elif i % 5 == 0 do
            result = push(result, "Buzz")
          else
            result = push(result, to_string(i))
          end
        end
        """)
        let result = try interp.globalEnv.get("result")
        if case .list(let items) = result {
            XCTAssertEqual(items[0], .string("1"))
            XCTAssertEqual(items[2], .string("Fizz"))
            XCTAssertEqual(items[4], .string("Buzz"))
            XCTAssertEqual(items[14], .string("FizzBuzz"))
        } else { XCTFail("Expected list") }
    }

    // MARK: - Fibonacci

    func testFibonacci() throws {
        let interp = try run("""
        fn fib(n) do
          if n <= 1 do
            return n
          end
          return fib(n - 1) + fib(n - 2)
        end
        let result = fib(10)
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .int(55))
    }

    // MARK: - Higher-order Function Pipeline

    func testPipelineWithHigherOrder() throws {
        let interp = try run("""
        let nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let result = nums
          |> filter(fn(x) => x % 2 == 0)
          |> map(fn(x) => x * x)
          |> sum()
        """)
        // even: 2,4,6,8,10 -> squared: 4,16,36,64,100 -> sum: 220
        XCTAssertEqual(try interp.globalEnv.get("result"), .int(220))
    }

    // MARK: - Struct with Methods

    func testPointDistance() throws {
        let interp = try run("""
        struct Point do
          x
          y

          fn distance(other) do
            let dx = self.x - other.x
            let dy = self.y - other.y
            return sqrt(dx * dx + dy * dy)
          end
        end
        let p1 = Point(x: 0, y: 0)
        let p2 = Point(x: 3, y: 4)
        let dist = p1.distance(p2)
        """)
        XCTAssertEqual(try interp.globalEnv.get("dist"), .float(5.0))
    }

    // MARK: - Nested Functions and Closures

    func testCounter() throws {
        let interp = try run("""
        fn make_counter() do
          var count = 0
          fn increment() do
            count = count + 1
            return count
          end
          return increment
        end
        let counter = make_counter()
        let a = counter()
        let b = counter()
        let c = counter()
        """)
        XCTAssertEqual(try interp.globalEnv.get("a"), .int(1))
        XCTAssertEqual(try interp.globalEnv.get("b"), .int(2))
        XCTAssertEqual(try interp.globalEnv.get("c"), .int(3))
    }

    // MARK: - Pattern Matching with Range

    func testMatchRange() throws {
        let interp = try run("""
        fn classify(n) do
          var result = ""
          match n
            case 0 => result = "zero"
            case 1..10 => result = "small"
            case 11..100 => result = "medium"
            case x => result = "big"
          end
          return result
        end
        let r1 = classify(0)
        let r2 = classify(5)
        let r3 = classify(50)
        let r4 = classify(200)
        """)
        XCTAssertEqual(try interp.globalEnv.get("r1"), .string("zero"))
        XCTAssertEqual(try interp.globalEnv.get("r2"), .string("small"))
        XCTAssertEqual(try interp.globalEnv.get("r3"), .string("medium"))
        XCTAssertEqual(try interp.globalEnv.get("r4"), .string("big"))
    }

    // MARK: - Try/Catch with Thrown Value

    func testThrowCatch() throws {
        let interp = try run("""
        var result = ""
        try do
          throw("something went wrong")
        catch error do
          result = to_string(error)
        end
        """)
        XCTAssertEqual(try interp.globalEnv.get("result"), .string("something went wrong"))
    }

    // MARK: - String Methods

    func testStringMethods() throws {
        let interp = try run("""
        let s = "Hello, World!"
        let parts = s.split(", ")
        let up = s.upper()
        let lo = s.lower()
        let trimmed = "  hi  ".trim()
        """)
        XCTAssertEqual(try interp.globalEnv.get("parts"), .list([.string("Hello"), .string("World!")]))
        XCTAssertEqual(try interp.globalEnv.get("up"), .string("HELLO, WORLD!"))
        XCTAssertEqual(try interp.globalEnv.get("lo"), .string("hello, world!"))
        XCTAssertEqual(try interp.globalEnv.get("trimmed"), .string("hi"))
    }

    // MARK: - Map Operations

    func testMapOperations() throws {
        let interp = try run("""
        let m = {name: "Claudine", version: "0.1"}
        let k = keys(m)
        let v = values(m)
        let has = has_key(m, "name")
        let merged = merge(m, {author: "user"})
        """)
        XCTAssertEqual(try interp.globalEnv.get("has"), .bool(true))
        if case .map(let m) = try interp.globalEnv.get("merged") {
            XCTAssertEqual(m["author"], .string("user"))
            XCTAssertEqual(m["name"], .string("Claudine"))
        } else { XCTFail("Expected map") }
    }

    // MARK: - Complex Nested Logic

    func testNestedMatchInLoop() throws {
        let interp = try run("""
        var results = []
        for i in range(1, 6) do
          var label = ""
          match i
            case 1 => label = "one"
            case 2 => label = "two"
            case n => label = to_string(n)
          end
          results = push(results, label)
        end
        """)
        XCTAssertEqual(try interp.globalEnv.get("results"),
            .list([.string("one"), .string("two"), .string("3"), .string("4"), .string("5")]))
    }

    // MARK: - Default Parameters

    func testDefaultParams() throws {
        let interp = try run("""
        fn greet(name, greeting = "Hello") do
          return greeting + ", " + name + "!"
        end
        let r1 = greet("World")
        let r2 = greet("World", "Hi")
        """)
        XCTAssertEqual(try interp.globalEnv.get("r1"), .string("Hello, World!"))
        XCTAssertEqual(try interp.globalEnv.get("r2"), .string("Hi, World!"))
    }

    // MARK: - List Methods

    func testListMethods() throws {
        let interp = try run("""
        let list = [1, 2, 3]
        let with4 = list.push(4)
        let rev = list.reverse()
        let has2 = list.contains(2)
        let joined = ["a", "b", "c"].join("-")
        """)
        XCTAssertEqual(try interp.globalEnv.get("with4"), .list([.int(1), .int(2), .int(3), .int(4)]))
        XCTAssertEqual(try interp.globalEnv.get("rev"), .list([.int(3), .int(2), .int(1)]))
        XCTAssertEqual(try interp.globalEnv.get("has2"), .bool(true))
        XCTAssertEqual(try interp.globalEnv.get("joined"), .string("a-b-c"))
    }
}
