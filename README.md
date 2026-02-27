# Claudine

A programming language for the AI era.

Claudine is a dynamically-typed, functional-first interpreted language designed for AI-assisted CLI tool development. The core idea: if an AI agent writes most of the code while a human directs, evaluates, and tests, the language should be optimized for that workflow — easy for AI to generate correctly, easy for humans to read and audit, and with first-class AI integration built in.

## Quick Start

```bash
# Build
swift build -c release

# Install (optional)
cp .build/release/claudine /usr/local/bin/claudine

# Run a script
claudine examples/hello.cln

# Launch the REPL
claudine
```

## Language Overview

```claudine
# Variables
let name = "World"          # immutable
var counter = 0             # mutable

# Functions
fn greet(name) do
  println("Hello, {name}!")
end

fn double(x) => x * 2      # single-expression shorthand

# Control flow
if counter > 10 do
  println("big")
elif counter > 5 do
  println("medium")
else
  println("small")
end

# Loops
for item in [1, 2, 3] do
  println(item)
end

# Pattern matching
match value
  case 0 => println("zero")
  case 1..10 => println("small")
  case n => println("other: {n}")
end

# Pipeline operator
let result = [1, 2, 3, 4, 5]
  |> filter(fn(x) => x > 2)
  |> map(fn(x) => x * x)
  |> sum()

# Structs
struct Point do
  x
  y

  fn distance(other) do
    let dx = self.x - other.x
    let dy = self.y - other.y
    return sqrt(dx * dx + dy * dy)
  end
end

let p = Point(x: 3, y: 4)

# AI integration (requires ANTHROPIC_API_KEY)
let answer = ask("What is the capital of France?")

let review = ask(
  "Review this code: {source}",
  model: "sonnet",
  temperature: 0.2,
  system: "You are a senior code reviewer."
)
```

## Features

- **Dynamically typed** with int, float, string, bool, nil, list, map, function, and struct types
- **Immutable by default** — `let` for constants, `var` for mutables
- **First-class functions** — closures, higher-order functions, recursion
- **`do`/`end` blocks** — no brace counting, no indentation sensitivity
- **String interpolation** — `"Hello, {name}!"`
- **Pipeline operator** — `data |> transform() |> output()` for readable data flow
- **Pattern matching** — `match`/`case` with literals, ranges, and variable capture
- **Structs** with fields and methods
- **Error handling** — `try`/`catch` blocks
- **Module system** — `import "file.cln"`
- **CLI argument parsing** — built-in `args` block for defining CLI interfaces
- **AI integration** — `ask()` calls the Claude API with model, temperature, system prompt, and structured format options
- **Interactive REPL** — arrow keys, history, tab completion, parenthesis matching

## Built-in Functions

| Category | Functions |
|----------|-----------|
| **I/O** | `print`, `println`, `input`, `read_file`, `write_file`, `append_file`, `file_exists` |
| **String** | `split`, `join`, `trim`, `replace`, `contains`, `starts_with`, `ends_with`, `length`, `upper`, `lower` |
| **List** | `push`, `pop`, `map`, `filter`, `reduce`, `sort`, `reverse`, `flatten`, `zip`, `sum` |
| **Map** | `keys`, `values`, `has_key`, `merge` |
| **Math** | `abs`, `min`, `max`, `floor`, `ceil`, `round`, `sqrt`, `random` |
| **Type** | `type_of`, `to_string`, `to_int`, `to_float` |
| **System** | `exec`, `env`, `exit`, `sleep`, `range`, `throw` |
| **AI** | `ask` |

## AI Integration

Set your API key and use `ask()` to call Claude from any Claudine script:

```bash
export ANTHROPIC_API_KEY=your-key-here
```

```claudine
# Simple question
let answer = ask("Explain recursion in one sentence.")

# With options
let summary = ask(
  "Summarize this text: {content}",
  model: "sonnet",
  temperature: 0.3,
  system: "You are a helpful assistant."
)

# Structured response
let result = ask(
  "Classify the sentiment: {text}",
  format: {sentiment: "string", confidence: "number"}
)
```

Available models: `opus`, `sonnet`, `haiku` (or any full model ID).

## CLI Argument Parsing

Claudine scripts can define their own CLI interfaces:

```claudine
args do
  arg file: string, "Input file path"
  option output: string, "Output file", default: "out.txt"
  flag verbose: bool, "Enable verbose output", short: "v"
end

println("Processing {file}...")
if verbose do
  println("Output: {output}")
end
```

```bash
claudine script.cln input.txt --output result.txt --verbose
```

## VS Code Extension

Syntax highlighting for `.cln` files:

```bash
ln -s /path/to/Claudine/claudine-vscode ~/.vscode/extensions/claudine-lang
```

Restart VS Code and `.cln` files will have full highlighting for keywords, strings, comments, operators, and built-in functions.

## Building & Testing

```bash
swift build              # debug build
swift build -c release   # optimized release build
swift test               # run test suite (129 tests)
```

## File Extension

Claudine source files use the `.cln` extension. Scripts can use a shebang for direct execution:

```claudine
#!/usr/bin/env claudine
println("Hello from Claudine!")
```

## License

MIT
