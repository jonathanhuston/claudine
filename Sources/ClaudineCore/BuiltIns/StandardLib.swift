import Foundation

/// Standard library of built-in functions for Claudine.
public struct StandardLib {
    public static func register(in env: Environment) {
        // I/O
        env.define("print", value: .builtInFunction(BuiltInFunction(name: "print", arity: nil) { args, _ in
            let output = args.map { $0.description }.joined(separator: " ")
            Swift.print(output, terminator: "")
            return .nil
        }), isMutable: false)

        env.define("println", value: .builtInFunction(BuiltInFunction(name: "println", arity: nil) { args, _ in
            let output = args.map { $0.description }.joined(separator: " ")
            Swift.print(output)
            return .nil
        }), isMutable: false)

        env.define("input", value: .builtInFunction(BuiltInFunction(name: "input", arity: nil) { args, _ in
            if let prompt = args.first {
                Swift.print(prompt.description, terminator: "")
            }
            guard let line = readLine() else { return .nil }
            return .string(line)
        }), isMutable: false)

        // Type
        env.define("type_of", value: .builtInFunction(BuiltInFunction(name: "type_of", arity: 1) { args, _ in
            return .string(args[0].typeName)
        }), isMutable: false)

        env.define("to_string", value: .builtInFunction(BuiltInFunction(name: "to_string", arity: 1) { args, _ in
            return .string(args[0].description)
        }), isMutable: false)

        env.define("to_int", value: .builtInFunction(BuiltInFunction(name: "to_int", arity: 1) { args, loc in
            switch args[0] {
            case .int: return args[0]
            case .float(let v): return .int(Int(v))
            case .string(let s):
                if let v = Int(s) { return .int(v) }
                throw RuntimeError.typeMismatch(expected: "convertible to int", got: "string(\(s))", loc)
            case .bool(let v): return .int(v ? 1 : 0)
            default: throw RuntimeError.typeMismatch(expected: "convertible to int", got: args[0].typeName, loc)
            }
        }), isMutable: false)

        env.define("to_float", value: .builtInFunction(BuiltInFunction(name: "to_float", arity: 1) { args, loc in
            switch args[0] {
            case .float: return args[0]
            case .int(let v): return .float(Double(v))
            case .string(let s):
                if let v = Double(s) { return .float(v) }
                throw RuntimeError.typeMismatch(expected: "convertible to float", got: "string(\(s))", loc)
            default: throw RuntimeError.typeMismatch(expected: "convertible to float", got: args[0].typeName, loc)
            }
        }), isMutable: false)

        // String functions
        env.define("length", value: .builtInFunction(BuiltInFunction(name: "length", arity: 1) { args, loc in
            switch args[0] {
            case .string(let s): return .int(s.count)
            case .list(let l): return .int(l.count)
            case .map(let m): return .int(m.count)
            default: throw RuntimeError.typeMismatch(expected: "string, list, or map", got: args[0].typeName, loc)
            }
        }), isMutable: false)

        env.define("split", value: .builtInFunction(BuiltInFunction(name: "split", arity: 2) { args, loc in
            guard case .string(let s) = args[0], case .string(let sep) = args[1] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }
            let parts = s.components(separatedBy: sep)
            return .list(parts.map { .string($0) })
        }), isMutable: false)

        env.define("join", value: .builtInFunction(BuiltInFunction(name: "join", arity: 2) { args, loc in
            guard case .list(let items) = args[0], case .string(let sep) = args[1] else {
                throw RuntimeError.typeMismatch(expected: "list and string", got: "\(args[0].typeName) and \(args[1].typeName)", loc)
            }
            let strs = items.map { $0.description }
            return .string(strs.joined(separator: sep))
        }), isMutable: false)

        env.define("trim", value: .builtInFunction(BuiltInFunction(name: "trim", arity: 1) { args, loc in
            guard case .string(let s) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }
            return .string(s.trimmingCharacters(in: .whitespacesAndNewlines))
        }), isMutable: false)

        env.define("replace", value: .builtInFunction(BuiltInFunction(name: "replace", arity: 3) { args, loc in
            guard case .string(let s) = args[0], case .string(let old) = args[1], case .string(let new) = args[2] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }
            return .string(s.replacingOccurrences(of: old, with: new))
        }), isMutable: false)

        env.define("contains", value: .builtInFunction(BuiltInFunction(name: "contains", arity: 2) { args, loc in
            switch (args[0], args[1]) {
            case (.string(let s), .string(let sub)):
                return .bool(s.contains(sub))
            case (.list(let items), let value):
                return .bool(items.contains(value))
            default:
                throw RuntimeError.typeMismatch(expected: "string or list", got: args[0].typeName, loc)
            }
        }), isMutable: false)

        env.define("starts_with", value: .builtInFunction(BuiltInFunction(name: "starts_with", arity: 2) { args, loc in
            guard case .string(let s) = args[0], case .string(let prefix) = args[1] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }
            return .bool(s.hasPrefix(prefix))
        }), isMutable: false)

        env.define("ends_with", value: .builtInFunction(BuiltInFunction(name: "ends_with", arity: 2) { args, loc in
            guard case .string(let s) = args[0], case .string(let suffix) = args[1] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }
            return .bool(s.hasSuffix(suffix))
        }), isMutable: false)

        env.define("upper", value: .builtInFunction(BuiltInFunction(name: "upper", arity: 1) { args, loc in
            guard case .string(let s) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }
            return .string(s.uppercased())
        }), isMutable: false)

        env.define("lower", value: .builtInFunction(BuiltInFunction(name: "lower", arity: 1) { args, loc in
            guard case .string(let s) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }
            return .string(s.lowercased())
        }), isMutable: false)

        // List functions
        env.define("push", value: .builtInFunction(BuiltInFunction(name: "push", arity: 2) { args, loc in
            guard case .list(var items) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "list", got: args[0].typeName, loc)
            }
            items.append(args[1])
            return .list(items)
        }), isMutable: false)

        env.define("pop", value: .builtInFunction(BuiltInFunction(name: "pop", arity: 1) { args, loc in
            guard case .list(var items) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "list", got: args[0].typeName, loc)
            }
            guard !items.isEmpty else {
                throw RuntimeError.indexOutOfBounds(0, count: 0, loc)
            }
            return items.removeLast()
        }), isMutable: false)

        env.define("map", value: .builtInFunction(BuiltInFunction(name: "map", arity: 2) { args, loc in
            guard case .list(let items) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "list", got: args[0].typeName, loc)
            }
            let fn = args[1]
            let interpreter = Interpreter()
            var result: [Value] = []
            for item in items {
                let val = try interpreter.callFunction(fn, args: [item], namedArgs: [:], loc: loc)
                result.append(val)
            }
            return .list(result)
        }), isMutable: false)

        env.define("filter", value: .builtInFunction(BuiltInFunction(name: "filter", arity: 2) { args, loc in
            guard case .list(let items) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "list", got: args[0].typeName, loc)
            }
            let fn = args[1]
            let interpreter = Interpreter()
            var result: [Value] = []
            for item in items {
                let val = try interpreter.callFunction(fn, args: [item], namedArgs: [:], loc: loc)
                if val.isTruthy {
                    result.append(item)
                }
            }
            return .list(result)
        }), isMutable: false)

        env.define("reduce", value: .builtInFunction(BuiltInFunction(name: "reduce", arity: 3) { args, loc in
            guard case .list(let items) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "list", got: args[0].typeName, loc)
            }
            var accumulator = args[1]
            let fn = args[2]
            let interpreter = Interpreter()
            for item in items {
                accumulator = try interpreter.callFunction(fn, args: [accumulator, item], namedArgs: [:], loc: loc)
            }
            return accumulator
        }), isMutable: false)

        env.define("sort", value: .builtInFunction(BuiltInFunction(name: "sort", arity: 1) { args, loc in
            guard case .list(let items) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "list", got: args[0].typeName, loc)
            }
            let sorted = try items.sorted { a, b in
                switch (a, b) {
                case (.int(let x), .int(let y)): return x < y
                case (.float(let x), .float(let y)): return x < y
                case (.string(let x), .string(let y)): return x < y
                case (.int(let x), .float(let y)): return Double(x) < y
                case (.float(let x), .int(let y)): return x < Double(y)
                default: throw RuntimeError.typeMismatch(expected: "comparable", got: "\(a.typeName) and \(b.typeName)", loc)
                }
            }
            return .list(sorted)
        }), isMutable: false)

        env.define("reverse", value: .builtInFunction(BuiltInFunction(name: "reverse", arity: 1) { args, loc in
            switch args[0] {
            case .list(let items): return .list(items.reversed())
            case .string(let s): return .string(String(s.reversed()))
            default: throw RuntimeError.typeMismatch(expected: "list or string", got: args[0].typeName, loc)
            }
        }), isMutable: false)

        env.define("flatten", value: .builtInFunction(BuiltInFunction(name: "flatten", arity: 1) { args, loc in
            guard case .list(let items) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "list", got: args[0].typeName, loc)
            }
            var result: [Value] = []
            for item in items {
                if case .list(let inner) = item {
                    result.append(contentsOf: inner)
                } else {
                    result.append(item)
                }
            }
            return .list(result)
        }), isMutable: false)

        env.define("zip", value: .builtInFunction(BuiltInFunction(name: "zip", arity: 2) { args, loc in
            guard case .list(let a) = args[0], case .list(let b) = args[1] else {
                throw RuntimeError.typeMismatch(expected: "list", got: args[0].typeName, loc)
            }
            let count = min(a.count, b.count)
            var result: [Value] = []
            for i in 0..<count {
                result.append(.list([a[i], b[i]]))
            }
            return .list(result)
        }), isMutable: false)

        env.define("sum", value: .builtInFunction(BuiltInFunction(name: "sum", arity: 1) { args, loc in
            guard case .list(let items) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "list", got: args[0].typeName, loc)
            }
            var intSum = 0
            var isFloat = false
            var floatSum = 0.0
            for item in items {
                switch item {
                case .int(let v):
                    if isFloat { floatSum += Double(v) }
                    else { intSum += v }
                case .float(let v):
                    if !isFloat { floatSum = Double(intSum); isFloat = true }
                    floatSum += v
                default:
                    throw RuntimeError.typeMismatch(expected: "number", got: item.typeName, loc)
                }
            }
            return isFloat ? .float(floatSum) : .int(intSum)
        }), isMutable: false)

        // Map functions
        env.define("keys", value: .builtInFunction(BuiltInFunction(name: "keys", arity: 1) { args, loc in
            guard case .map(let m) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "map", got: args[0].typeName, loc)
            }
            return .list(m.keys.map { .string($0) })
        }), isMutable: false)

        env.define("values", value: .builtInFunction(BuiltInFunction(name: "values", arity: 1) { args, loc in
            guard case .map(let m) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "map", got: args[0].typeName, loc)
            }
            return .list(m.values)
        }), isMutable: false)

        env.define("has_key", value: .builtInFunction(BuiltInFunction(name: "has_key", arity: 2) { args, loc in
            guard case .map(let m) = args[0], case .string(let key) = args[1] else {
                throw RuntimeError.typeMismatch(expected: "map and string", got: "\(args[0].typeName) and \(args[1].typeName)", loc)
            }
            return .bool(m[key] != nil)
        }), isMutable: false)

        env.define("merge", value: .builtInFunction(BuiltInFunction(name: "merge", arity: 2) { args, loc in
            guard case .map(var a) = args[0], case .map(let b) = args[1] else {
                throw RuntimeError.typeMismatch(expected: "map", got: args[0].typeName, loc)
            }
            for pair in b.pairs {
                a[pair.key] = pair.value
            }
            return .map(a)
        }), isMutable: false)

        // Math functions
        env.define("abs", value: .builtInFunction(BuiltInFunction(name: "abs", arity: 1) { args, loc in
            switch args[0] {
            case .int(let v): return .int(Swift.abs(v))
            case .float(let v): return .float(Swift.abs(v))
            default: throw RuntimeError.typeMismatch(expected: "number", got: args[0].typeName, loc)
            }
        }), isMutable: false)

        env.define("min", value: .builtInFunction(BuiltInFunction(name: "min", arity: nil) { args, loc in
            guard !args.isEmpty else { throw RuntimeError.arityMismatch(expected: 1, got: 0, loc) }
            if args.count == 1, case .list(let items) = args[0] {
                guard !items.isEmpty else { throw RuntimeError.generalError("min() called on empty list", loc) }
                return try items.reduce(items[0]) { best, item in
                    switch (best, item) {
                    case (.int(let a), .int(let b)): return a <= b ? best : item
                    case (.float(let a), .float(let b)): return a <= b ? best : item
                    case (.int(let a), .float(let b)): return Double(a) <= b ? best : item
                    case (.float(let a), .int(let b)): return a <= Double(b) ? best : item
                    default: throw RuntimeError.typeMismatch(expected: "number", got: item.typeName, loc)
                    }
                }
            }
            return try args.reduce(args[0]) { best, item in
                switch (best, item) {
                case (.int(let a), .int(let b)): return a <= b ? best : item
                case (.float(let a), .float(let b)): return a <= b ? best : item
                case (.int(let a), .float(let b)): return Double(a) <= b ? best : item
                case (.float(let a), .int(let b)): return a <= Double(b) ? best : item
                default: throw RuntimeError.typeMismatch(expected: "number", got: item.typeName, loc)
                }
            }
        }), isMutable: false)

        env.define("max", value: .builtInFunction(BuiltInFunction(name: "max", arity: nil) { args, loc in
            guard !args.isEmpty else { throw RuntimeError.arityMismatch(expected: 1, got: 0, loc) }
            if args.count == 1, case .list(let items) = args[0] {
                guard !items.isEmpty else { throw RuntimeError.generalError("max() called on empty list", loc) }
                return try items.reduce(items[0]) { best, item in
                    switch (best, item) {
                    case (.int(let a), .int(let b)): return a >= b ? best : item
                    case (.float(let a), .float(let b)): return a >= b ? best : item
                    case (.int(let a), .float(let b)): return Double(a) >= b ? best : item
                    case (.float(let a), .int(let b)): return a >= Double(b) ? best : item
                    default: throw RuntimeError.typeMismatch(expected: "number", got: item.typeName, loc)
                    }
                }
            }
            return try args.reduce(args[0]) { best, item in
                switch (best, item) {
                case (.int(let a), .int(let b)): return a >= b ? best : item
                case (.float(let a), .float(let b)): return a >= b ? best : item
                case (.int(let a), .float(let b)): return Double(a) >= b ? best : item
                case (.float(let a), .int(let b)): return a >= Double(b) ? best : item
                default: throw RuntimeError.typeMismatch(expected: "number", got: item.typeName, loc)
                }
            }
        }), isMutable: false)

        env.define("floor", value: .builtInFunction(BuiltInFunction(name: "floor", arity: 1) { args, loc in
            switch args[0] {
            case .float(let v): return .int(Int(Foundation.floor(v)))
            case .int: return args[0]
            default: throw RuntimeError.typeMismatch(expected: "number", got: args[0].typeName, loc)
            }
        }), isMutable: false)

        env.define("ceil", value: .builtInFunction(BuiltInFunction(name: "ceil", arity: 1) { args, loc in
            switch args[0] {
            case .float(let v): return .int(Int(Foundation.ceil(v)))
            case .int: return args[0]
            default: throw RuntimeError.typeMismatch(expected: "number", got: args[0].typeName, loc)
            }
        }), isMutable: false)

        env.define("round", value: .builtInFunction(BuiltInFunction(name: "round", arity: 1) { args, loc in
            switch args[0] {
            case .float(let v): return .int(Int(Foundation.round(v)))
            case .int: return args[0]
            default: throw RuntimeError.typeMismatch(expected: "number", got: args[0].typeName, loc)
            }
        }), isMutable: false)

        env.define("sqrt", value: .builtInFunction(BuiltInFunction(name: "sqrt", arity: 1) { args, loc in
            switch args[0] {
            case .int(let v): return .float(Foundation.sqrt(Double(v)))
            case .float(let v): return .float(Foundation.sqrt(v))
            default: throw RuntimeError.typeMismatch(expected: "number", got: args[0].typeName, loc)
            }
        }), isMutable: false)

        env.define("random", value: .builtInFunction(BuiltInFunction(name: "random", arity: nil) { args, _ in
            if args.isEmpty {
                return .float(Double.random(in: 0..<1))
            }
            if args.count == 2, case .int(let lo) = args[0], case .int(let hi) = args[1] {
                return .int(Int.random(in: lo...hi))
            }
            return .float(Double.random(in: 0..<1))
        }), isMutable: false)

        // System functions
        env.define("exec", value: .builtInFunction(BuiltInFunction(name: "exec", arity: 1) { args, loc in
            guard case .string(let cmd) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", cmd]
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                return .string(output.hasSuffix("\n") ? String(output.dropLast()) : output)
            } catch {
                throw RuntimeError.generalError("exec failed: \(error.localizedDescription)", loc)
            }
        }), isMutable: false)

        env.define("env", value: .builtInFunction(BuiltInFunction(name: "env", arity: 1) { args, loc in
            guard case .string(let name) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }
            if let value = ProcessInfo.processInfo.environment[name] {
                return .string(value)
            }
            return .nil
        }), isMutable: false)

        env.define("exit", value: .builtInFunction(BuiltInFunction(name: "exit", arity: nil) { args, _ in
            let code = args.first.flatMap { if case .int(let v) = $0 { return v } else { return nil } } ?? 0
            Foundation.exit(Int32(code))
        }), isMutable: false)

        env.define("sleep", value: .builtInFunction(BuiltInFunction(name: "sleep", arity: 1) { args, loc in
            guard case .int(let ms) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "int (milliseconds)", got: args[0].typeName, loc)
            }
            Thread.sleep(forTimeInterval: Double(ms) / 1000.0)
            return .nil
        }), isMutable: false)

        // Throw
        env.define("throw", value: .builtInFunction(BuiltInFunction(name: "throw", arity: 1) { args, loc in
            throw RuntimeError.userThrownError(args[0], loc)
        }), isMutable: false)

        // Range
        env.define("range", value: .builtInFunction(BuiltInFunction(name: "range", arity: nil) { args, loc in
            if args.count == 1, case .int(let end) = args[0] {
                return .list((0..<end).map { .int($0) })
            }
            if args.count == 2, case .int(let start) = args[0], case .int(let end) = args[1] {
                return .list((start..<end).map { .int($0) })
            }
            if args.count == 3, case .int(let start) = args[0], case .int(let end) = args[1], case .int(let step) = args[2] {
                var result: [Value] = []
                var i = start
                while step > 0 ? i < end : i > end {
                    result.append(.int(i))
                    i += step
                }
                return .list(result)
            }
            throw RuntimeError.typeMismatch(expected: "int arguments", got: "invalid args", loc)
        }), isMutable: false)
    }

    // MARK: - Method dispatch on built-in types

    public static func callMethod(on obj: Value, method: String, args: [Value], loc: SourceLocation?) throws -> Value {
        switch obj {
        case .string(let s):
            return try stringMethod(s, method: method, args: args, loc: loc)
        case .list(let items):
            return try listMethod(items, method: method, args: args, loc: loc)
        case .map(let m):
            return try mapMethod(m, method: method, args: args, loc: loc)
        default:
            throw RuntimeError.undefinedProperty(method, loc)
        }
    }

    private static func stringMethod(_ s: String, method: String, args: [Value], loc: SourceLocation?) throws -> Value {
        switch method {
        case "length": return .int(s.count)
        case "split":
            guard let sep = args.first, case .string(let sepStr) = sep else {
                throw RuntimeError.arityMismatch(expected: 1, got: args.count, loc)
            }
            return .list(s.components(separatedBy: sepStr).map { .string($0) })
        case "trim": return .string(s.trimmingCharacters(in: .whitespacesAndNewlines))
        case "upper": return .string(s.uppercased())
        case "lower": return .string(s.lowercased())
        case "contains":
            guard case .string(let sub) = args.first else { throw RuntimeError.arityMismatch(expected: 1, got: 0, loc) }
            return .bool(s.contains(sub))
        case "starts_with":
            guard case .string(let prefix) = args.first else { throw RuntimeError.arityMismatch(expected: 1, got: 0, loc) }
            return .bool(s.hasPrefix(prefix))
        case "ends_with":
            guard case .string(let suffix) = args.first else { throw RuntimeError.arityMismatch(expected: 1, got: 0, loc) }
            return .bool(s.hasSuffix(suffix))
        case "replace":
            guard args.count == 2, case .string(let old) = args[0], case .string(let new) = args[1] else {
                throw RuntimeError.arityMismatch(expected: 2, got: args.count, loc)
            }
            return .string(s.replacingOccurrences(of: old, with: new))
        default:
            throw RuntimeError.undefinedProperty(method, loc)
        }
    }

    private static func listMethod(_ items: [Value], method: String, args: [Value], loc: SourceLocation?) throws -> Value {
        switch method {
        case "length": return .int(items.count)
        case "push":
            guard let val = args.first else { throw RuntimeError.arityMismatch(expected: 1, got: 0, loc) }
            return .list(items + [val])
        case "pop":
            guard !items.isEmpty else { throw RuntimeError.indexOutOfBounds(0, count: 0, loc) }
            return items.last!
        case "contains":
            guard let val = args.first else { throw RuntimeError.arityMismatch(expected: 1, got: 0, loc) }
            return .bool(items.contains(val))
        case "reverse":
            return .list(items.reversed())
        case "join":
            guard case .string(let sep) = args.first else { throw RuntimeError.arityMismatch(expected: 1, got: 0, loc) }
            return .string(items.map { $0.description }.joined(separator: sep))
        default:
            throw RuntimeError.undefinedProperty(method, loc)
        }
    }

    private static func mapMethod(_ m: OrderedMap, method: String, args: [Value], loc: SourceLocation?) throws -> Value {
        switch method {
        case "keys": return .list(m.keys.map { .string($0) })
        case "values": return .list(m.values)
        case "has_key":
            guard case .string(let key) = args.first else { throw RuntimeError.arityMismatch(expected: 1, got: 0, loc) }
            return .bool(m[key] != nil)
        default:
            throw RuntimeError.undefinedProperty(method, loc)
        }
    }
}
