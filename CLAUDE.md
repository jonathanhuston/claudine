# Claudine

Claudine is a dynamically-typed, functional-first interpreted programming language implemented in Swift, designed for AI-assisted CLI tool development.

## Build & Test

```bash
swift build              # debug build → .build/debug/claudine
swift build -c release   # optimized build → .build/release/claudine
swift test               # run all 129 tests
```

## Run

```bash
swift run claudine examples/hello.cln
swift run claudine                        # launches REPL
```

## Architecture

Tree-walking interpreter: Lexer → Parser (recursive descent) → AST → Interpreter.

Two SPM targets:
- `claudine` — CLI executable (depends on ArgumentParser)
- `ClaudineCore` — library containing the full interpreter (testable)

Note: The AST call argument type is named `CallArgument` (not `Argument`) to avoid collision with swift-argument-parser.

## Known Gaps / Future Work

These are features from the original design that are partially implemented or deferred. Tackle after real-world usage informs priorities.

### REPL Ctrl-D (EOF) handling
Ctrl-D should exit the REPL cleanly but currently produces a terminal error. The `LineReaderError.EOF` catch is in place (using swift-commandlinekit's `LineReader`) but the error isn't being caught as expected. Needs debugging — may be a signal handling issue or the library throwing a different error type. For now, `exit`/`quit` commands work as the clean exit path.

### Streaming for ask()
The `ask()` built-in currently waits for the full API response. The plan called for streaming support that prints tokens as they arrive — important for long AI responses.

### Module system namespacing
`import "file.cln"` works (loads definitions into current scope). `import "file.cln" as alias` parses but doesn't fully namespace — it creates an empty map instead of exposing the module's definitions via `alias.name`.

### Mock API tests for AI integration
The AI lib has no test coverage since it makes real HTTP calls. Add tests with mock/stubbed API responses.

### REPL improvements (beyond line editing)
Tab completion for built-in functions and variables in scope. Syntax-highlighted input. `.load` command to load a file into the REPL session.

### Error recovery in parser
Currently the parser stops at the first error. Could collect multiple errors and report them all, or attempt recovery to continue parsing.

### Nested string interpolation
`"outer {"{inner}"}"` doesn't work — the inner string's quotes conflict. Would need the lexer to track interpolation depth.
