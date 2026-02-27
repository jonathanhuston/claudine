import Foundation
import CommandLineKit

/// Interactive Read-Eval-Print Loop for Claudine.
public class REPL {
    private let interpreter: Interpreter
    private let lineReader: LineReader?
    private var historyItems: [String] = []
    private let historyFile: String

    /// All Claudine keywords and built-in function names for tab completion.
    private static let completionWords: [String] = [
        // Keywords
        "let", "var", "fn", "do", "end", "if", "else", "elif",
        "for", "in", "while", "match", "case", "return", "break", "continue",
        "struct", "import", "as", "try", "catch", "args", "arg", "option", "flag",
        "true", "false", "nil", "and", "or", "not", "self",
        // Built-in functions
        "print", "println", "input", "read_file", "write_file", "append_file", "file_exists",
        "split", "join", "trim", "replace", "contains", "starts_with", "ends_with",
        "length", "upper", "lower",
        "push", "pop", "map", "filter", "reduce", "sort", "reverse", "flatten", "zip", "sum",
        "keys", "values", "has_key", "merge",
        "abs", "min", "max", "floor", "ceil", "round", "sqrt", "random",
        "type_of", "to_string", "to_int", "to_float",
        "exec", "env", "exit", "sleep", "throw", "range",
        "ask",
    ]

    public init() {
        self.interpreter = Interpreter()
        self.lineReader = LineReader()
        self.historyFile = NSHomeDirectory() + "/.claudine_history"

        if let lr = lineReader {
            lr.setHistoryMaxLength(500)
            try? lr.loadHistory(fromFile: historyFile)

            lr.setCompletionCallback { buffer in
                let partial = buffer.split(separator: " ").last.map(String.init) ?? buffer
                guard !partial.isEmpty else { return [] }
                let matches = REPL.completionWords.filter { $0.hasPrefix(partial) }
                let prefix = String(buffer.dropLast(partial.count))
                return matches.map { prefix + $0 }
            }
        }
    }

    public func run() {
        printBanner()

        guard let lr = lineReader else {
            runBasic()
            return
        }

        let promptProps = TextProperties(.green, nil, .bold)
        let parenProps = TextProperties(.red, nil, .bold)

        while true {
            do {
                let line = try lr.readLine(
                    prompt: "claudine> ",
                    maxCount: 4096,
                    strippingNewline: true,
                    promptProperties: promptProps,
                    readProperties: TextProperties.none,
                    parenProperties: parenProps
                )

                let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
                if trimmed.isEmpty { continue }

                // Exit commands (no dot prefix needed)
                if trimmed == "exit" || trimmed == "quit" {
                    saveHistory()
                    Swift.print("Goodbye!")
                    return
                }

                // REPL commands
                if trimmed.hasPrefix(".") {
                    addToHistory(lr, trimmed)
                    if handleCommand(trimmed) { continue }
                }

                // Multi-line input
                var source = line
                if needsMoreInput(source) {
                    while true {
                        guard let nextLine = try? lr.readLine(
                            prompt: "       .. ",
                            maxCount: 4096,
                            strippingNewline: true
                        ) else { break }
                        source += "\n" + nextLine
                        if !needsMoreInput(source) { break }
                    }
                }

                addToHistory(lr, source)
                executeSource(source)

            } catch let error as LineReaderError {
                switch error {
                case .CTRLC:
                    Swift.print("^C")
                    continue
                case .EOF:
                    Swift.print()
                    saveHistory()
                    return
                case .generalError(let msg):
                    Swift.print("Error: \(msg)")
                }
            } catch {
                Swift.print("Error: \(error)")
            }
        }

        saveHistory()
    }

    /// Fallback REPL for non-terminal environments.
    private func runBasic() {
        while true {
            Swift.print("claudine> ", terminator: "")
            fflush(stdout)

            guard var line = Swift.readLine() else {
                Swift.print()
                break
            }

            line = line.trimmingCharacters(in: CharacterSet.whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix(".") {
                if handleCommand(line) { continue }
            }

            var source = line
            if needsMoreInput(source) {
                while true {
                    Swift.print("       .. ", terminator: "")
                    fflush(stdout)
                    guard let nextLine = Swift.readLine() else { break }
                    source += "\n" + nextLine
                    if !needsMoreInput(source) { break }
                }
            }

            executeSource(source)
        }
    }

    private func printBanner() {
        Swift.print("Claudine v0.1.0 — Interactive REPL")
        Swift.print("Type .help for help, .exit to quit")
        Swift.print()
    }

    private func addToHistory(_ lr: LineReader, _ item: String) {
        lr.addHistory(item)
        historyItems.append(item)
    }

    private func handleCommand(_ command: String) -> Bool {
        switch command {
        case ".exit", ".quit", ".q":
            saveHistory()
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
            try? lineReader?.clearScreen()
            return true
        case ".history":
            for (i, item) in historyItems.enumerated() {
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
        var doCount = 0
        var endCount = 0
        var parenDepth = 0
        var bracketDepth = 0
        var braceDepth = 0

        let words = source.components(separatedBy: CharacterSet.whitespacesAndNewlines)
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

    private func saveHistory() {
        try? lineReader?.saveHistory(toFile: historyFile)
    }
}
