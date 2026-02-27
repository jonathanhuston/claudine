import ArgumentParser
import ClaudineCore
import Foundation

@main
struct ClaudineCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "claudine",
        abstract: "The Claudine programming language interpreter",
        version: "0.1.0"
    )

    @Argument(help: "Source file to execute (.cln)")
    var file: String?

    @Argument(parsing: .captureForPassthrough, help: "Arguments passed to the Claudine script")
    var scriptArgs: [String] = []

    mutating func run() throws {
        if let file = file {
            try runFile(file)
        } else {
            runREPL()
        }
    }

    private func runFile(_ path: String) throws {
        let url = URL(fileURLWithPath: path)
        let source: String
        do {
            source = try String(contentsOf: url, encoding: .utf8)
        } catch {
            print("Error: could not read file '\(path)': \(error.localizedDescription)")
            throw ExitCode.failure
        }

        do {
            let lexer = Lexer(source: source, fileName: path)
            let tokens = try lexer.tokenize()
            let parser = Parser(tokens: tokens, fileName: path)
            let ast = try parser.parse()
            let interpreter = Interpreter()
            interpreter.scriptArgs = scriptArgs
            interpreter.scriptPath = path
            try interpreter.execute(ast)
        } catch let error as LexerError {
            printError(error.description)
            throw ExitCode.failure
        } catch let error as ParseError {
            printError(error.description)
            throw ExitCode.failure
        } catch let error as RuntimeError {
            switch error {
            case .returnValue:
                break // top-level return is fine
            default:
                printError(error.description)
                throw ExitCode.failure
            }
        }
    }

    private func runREPL() {
        let repl = REPL()
        repl.run()
    }

    private func printError(_ message: String) {
        var stderr = FileHandle.standardError
        print("Error: \(message)", to: &stderr)
    }
}

extension FileHandle: @retroactive TextOutputStream {
    public func write(_ string: String) {
        let data = Data(string.utf8)
        self.write(data)
    }
}
