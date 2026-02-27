import Foundation

/// Interactive Read-Eval-Print Loop for Claudine.
public class REPL {
    private let interpreter: Interpreter
    private var history: [String] = []

    public init() {
        self.interpreter = Interpreter()
    }

    public func run() {
        printBanner()

        while true {
            Swift.print("claudine> ", terminator: "")
            fflush(stdout)

            guard var line = readLine() else {
                Swift.print()
                break
            }

            line = line.trimmingCharacters(in: .whitespaces)

            if line.isEmpty { continue }

            // REPL commands
            if line.hasPrefix(".") {
                if handleCommand(line) { continue }
            }

            // Multi-line input: if line ends with "do", collect until "end"
            var source = line
            if needsMoreInput(source) {
                while true {
                    Swift.print("       .. ", terminator: "")
                    fflush(stdout)
                    guard let nextLine = readLine() else { break }
                    source += "\n" + nextLine
                    if !needsMoreInput(source) { break }
                }
            }

            history.append(source)
            executeSource(source)
        }
    }

    private func printBanner() {
        Swift.print("Claudine v0.1.0 — Interactive REPL")
        Swift.print("Type .help for help, .exit to quit")
        Swift.print()
    }

    private func handleCommand(_ command: String) -> Bool {
        switch command {
        case ".exit", ".quit", ".q":
            Foundation.exit(0)
        case ".help":
            Swift.print("""
            Available commands:
              .help     Show this help message
              .exit     Exit the REPL
              .clear    Clear the screen
              .history  Show command history
              .reset    Reset the interpreter state
            """)
            return true
        case ".clear":
            Swift.print("\u{001B}[2J\u{001B}[H", terminator: "")
            return true
        case ".history":
            for (i, item) in history.enumerated() {
                Swift.print("  [\(i + 1)] \(item)")
            }
            return true
        case ".reset":
            interpreter.globalEnv = Environment()
            StandardLib.register(in: interpreter.globalEnv)
            IOLib.register(in: interpreter.globalEnv)
            AILib.register(in: interpreter.globalEnv)
            Swift.print("Interpreter state reset.")
            return true
        default:
            Swift.print("Unknown command: \(command). Type .help for help.")
            return true
        }
    }

    private func executeSource(_ source: String) {
        do {
            let lexer = Lexer(source: source, fileName: "<repl>")
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens: tokens, fileName: "<repl>")
            let stmts = try parser.parse()

            // If it's a single expression statement, print the result
            if stmts.count == 1, case .expression(let expr) = stmts[0] {
                let value = try interpreter.evaluate(expr, env: interpreter.globalEnv)
                if case .nil = value {
                    // Don't print nil for expression results
                } else {
                    Swift.print("=> \(value.inspectDescription)")
                }
            } else {
                try interpreter.execute(stmts)
            }
        } catch let error as LexerError {
            Swift.print("Error: \(error)")
        } catch let error as ParseError {
            Swift.print("Error: \(error)")
        } catch let error as RuntimeError {
            switch error {
            case .returnValue(let val):
                Swift.print("=> \(val.inspectDescription)")
            default:
                Swift.print("Error: \(error)")
            }
        } catch {
            Swift.print("Error: \(error)")
        }
    }

    private func needsMoreInput(_ source: String) -> Bool {
        // Count unmatched do/end, brackets, parens
        var doCount = 0
        var endCount = 0
        var parenDepth = 0
        var bracketDepth = 0
        var braceDepth = 0

        // Simple token-level counting
        let words = source.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            switch word {
            case "do": doCount += 1
            case "end": endCount += 1
            default: break
            }
        }

        for ch in source {
            switch ch {
            case "(": parenDepth += 1
            case ")": parenDepth -= 1
            case "[": bracketDepth += 1
            case "]": bracketDepth -= 1
            case "{": braceDepth += 1
            case "}": braceDepth -= 1
            default: break
            }
        }

        return doCount > endCount || parenDepth > 0 || bracketDepth > 0 || braceDepth > 0
    }
}
