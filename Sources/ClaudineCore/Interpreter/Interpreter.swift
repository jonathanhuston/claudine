import Foundation

/// Tree-walking interpreter for Claudine.
public class Interpreter {
    public var globalEnv: Environment
    public var scriptArgs: [String] = []
    public var scriptPath: String?
    private var importedModules: Set<String> = []

    public init() {
        self.globalEnv = Environment()
        StandardLib.register(in: globalEnv)
        IOLib.register(in: globalEnv)
        AILib.register(in: globalEnv)
    }

    public func execute(_ statements: [Statement]) throws {
        for stmt in statements {
            try executeStatement(stmt, env: globalEnv)
        }
    }

    // MARK: - Statement Execution

    public func executeStatement(_ stmt: Statement, env: Environment) throws {
        switch stmt {
        case .expression(let expr):
            _ = try evaluate(expr, env: env)

        case .letDecl(let name, let expr, _):
            let value = try evaluate(expr, env: env)
            env.define(name, value: value, isMutable: false)

        case .varDecl(let name, let expr, _):
            let value = try evaluate(expr, env: env)
            env.define(name, value: value, isMutable: true)

        case .fnDecl(let name, let params, let body, let isShorthand, _):
            let fn = Function(name: name, params: params, body: body, closure: env, isShorthand: isShorthand)
            env.define(name, value: .function(fn), isMutable: false)

        case .ifStmt(let condition, let body, let elifs, let elseBody, _):
            let condVal = try evaluate(condition, env: env)
            if condVal.isTruthy {
                let scope = Environment(parent: env)
                for s in body { try executeStatement(s, env: scope) }
            } else {
                var handled = false
                for (elifCond, elifBody) in elifs {
                    let val = try evaluate(elifCond, env: env)
                    if val.isTruthy {
                        let scope = Environment(parent: env)
                        for s in elifBody { try executeStatement(s, env: scope) }
                        handled = true
                        break
                    }
                }
                if !handled, let elseBody = elseBody {
                    let scope = Environment(parent: env)
                    for s in elseBody { try executeStatement(s, env: scope) }
                }
            }

        case .forStmt(let varName, let iterable, let body, let loc):
            let iterVal = try evaluate(iterable, env: env)
            let items: [Value]
            switch iterVal {
            case .list(let list):
                items = list
            case .string(let str):
                items = str.map { .string(String($0)) }
            case .map(let m):
                items = m.keys.map { .string($0) }
            default:
                throw RuntimeError.notIterable(iterVal.typeName, loc)
            }
            for item in items {
                let scope = Environment(parent: env)
                scope.define(varName, value: item, isMutable: false)
                do {
                    for s in body { try executeStatement(s, env: scope) }
                } catch RuntimeError.breakSignal {
                    break
                } catch RuntimeError.continueSignal {
                    continue
                }
            }

        case .whileStmt(let condition, let body, _):
            while true {
                let val = try evaluate(condition, env: env)
                if !val.isTruthy { break }
                let scope = Environment(parent: env)
                do {
                    for s in body { try executeStatement(s, env: scope) }
                } catch RuntimeError.breakSignal {
                    break
                } catch RuntimeError.continueSignal {
                    continue
                }
            }

        case .matchStmt(let expr, let cases, let loc):
            let value = try evaluate(expr, env: env)
            try executeMatch(value: value, cases: cases, env: env, loc: loc)

        case .returnStmt(let expr, _):
            let value = expr != nil ? try evaluate(expr!, env: env) : Value.nil
            throw RuntimeError.returnValue(value)

        case .breakStmt:
            throw RuntimeError.breakSignal

        case .continueStmt:
            throw RuntimeError.continueSignal

        case .structDecl(let name, let fields, let methods, _):
            var methodMap: [String: Statement] = [:]
            for method in methods {
                if case .fnDecl(let mName, _, _, _, _) = method {
                    methodMap[mName] = method
                }
            }
            let def = StructDef(name: name, fields: fields, methods: methodMap)
            env.define(name, value: .structDef(def), isMutable: false)

        case .importStmt(let path, let alias, let loc):
            try executeImport(path: path, alias: alias, env: env, loc: loc)

        case .tryCatch(let tryBody, let errorVar, let catchBody, _):
            do {
                let scope = Environment(parent: env)
                for s in tryBody { try executeStatement(s, env: scope) }
            } catch RuntimeError.returnValue {
                throw RuntimeError.returnValue(.nil) // re-throw return
            } catch RuntimeError.breakSignal, RuntimeError.continueSignal {
                throw RuntimeError.breakSignal // re-throw control flow
            } catch {
                let scope = Environment(parent: env)
                let errorValue: Value
                if let runtimeError = error as? RuntimeError {
                    if case .userThrownError(let val, _) = runtimeError {
                        errorValue = val
                    } else {
                        errorValue = .string(runtimeError.description)
                    }
                } else {
                    errorValue = .string(error.localizedDescription)
                }
                scope.define(errorVar, value: errorValue, isMutable: false)
                for s in catchBody { try executeStatement(s, env: scope) }
            }

        case .argsBlock(let defs, let loc):
            try executeArgsBlock(defs: defs, env: env, loc: loc)
        }
    }

    // MARK: - Expression Evaluation

    public func evaluate(_ expr: Expression, env: Environment) throws -> Value {
        switch expr {
        case .intLiteral(let v, _):
            return .int(v)
        case .floatLiteral(let v, _):
            return .float(v)
        case .stringLiteral(let v, _):
            return .string(v)
        case .boolLiteral(let v, _):
            return .bool(v)
        case .nilLiteral:
            return .nil

        case .interpolatedString(let parts, _):
            var result = ""
            for part in parts {
                switch part {
                case .literal(let s):
                    result += s
                case .expression(let e):
                    let val = try evaluate(e, env: env)
                    result += val.description
                }
            }
            return .string(result)

        case .identifier(let name, let loc):
            do {
                return try env.get(name)
            } catch {
                throw RuntimeError.undefinedVariable(name, loc)
            }

        case .selfExpr(let loc):
            do {
                return try env.get("self")
            } catch {
                throw RuntimeError.undefinedVariable("self", loc)
            }

        case .listLiteral(let elements, _):
            let values = try elements.map { try evaluate($0, env: env) }
            return .list(values)

        case .mapLiteral(let pairs, _):
            var map = OrderedMap()
            for (key, valExpr) in pairs {
                let val = try evaluate(valExpr, env: env)
                map[key] = val
            }
            return .map(map)

        case .binary(let left, let op, let right, let loc):
            return try evaluateBinary(left: left, op: op, right: right, env: env, loc: loc)

        case .unary(let op, let operand, let loc):
            let val = try evaluate(operand, env: env)
            switch op {
            case .negate:
                switch val {
                case .int(let v): return .int(-v)
                case .float(let v): return .float(-v)
                default: throw RuntimeError.typeMismatch(expected: "number", got: val.typeName, loc)
                }
            case .not:
                return .bool(!val.isTruthy)
            }

        case .pipeline(let left, let right, let loc):
            let leftVal = try evaluate(left, env: env)
            // Right side should be a call expression — inject left as first arg
            switch right {
            case .call(let callee, let args, let callLoc):
                // Evaluate: call callee with leftVal as first arg
                let fn = try evaluate(callee, env: env)
                var argValues: [Value] = [leftVal]
                for arg in args {
                    argValues.append(try evaluate(arg.value, env: env))
                }
                return try callFunction(fn, args: argValues, namedArgs: [:], loc: callLoc)

            case .identifier(_, let callLoc):
                // Treat as a zero-arg function call with leftVal piped in
                let fn = try evaluate(right, env: env)
                return try callFunction(fn, args: [leftVal], namedArgs: [:], loc: callLoc)

            default:
                throw RuntimeError.generalError("right side of |> must be a function call", loc)
            }

        case .call(let callee, let args, let loc):
            // Handle method calls on struct instances
            if case .fieldAccess(let obj, let method, _) = callee {
                return try callMethod(obj: obj, method: method, args: args, env: env, loc: loc)
            }
            let fn = try evaluate(callee, env: env)
            var positional: [Value] = []
            var named: [String: Value] = [:]
            for arg in args {
                let val = try evaluate(arg.value, env: env)
                if let label = arg.label {
                    named[label] = val
                } else {
                    positional.append(val)
                }
            }
            return try callFunction(fn, args: positional, namedArgs: named, loc: loc)

        case .index(let obj, let idx, let loc):
            let objVal = try evaluate(obj, env: env)
            let idxVal = try evaluate(idx, env: env)
            switch (objVal, idxVal) {
            case (.list(let list), .int(let i)):
                let index = i < 0 ? list.count + i : i
                guard index >= 0 && index < list.count else {
                    throw RuntimeError.indexOutOfBounds(i, count: list.count, loc)
                }
                return list[index]
            case (.map(let map), .string(let key)):
                return map[key] ?? .nil
            case (.string(let str), .int(let i)):
                let chars = Array(str)
                let index = i < 0 ? chars.count + i : i
                guard index >= 0 && index < chars.count else {
                    throw RuntimeError.indexOutOfBounds(i, count: chars.count, loc)
                }
                return .string(String(chars[index]))
            default:
                throw RuntimeError.typeMismatch(expected: "indexable", got: objVal.typeName, loc)
            }

        case .fieldAccess(let obj, let field, let loc):
            let objVal = try evaluate(obj, env: env)
            switch objVal {
            case .structInstance(let inst):
                if let val = inst.fields[field] {
                    return val
                }
                // Check for method
                if let methodStmt = inst.def.methods[field] {
                    if case .fnDecl(_, let params, let body, let isShorthand, _) = methodStmt {
                        let methodEnv = Environment(parent: env)
                        methodEnv.define("self", value: objVal, isMutable: false)
                        return .function(Function(name: field, params: params, body: body, closure: methodEnv, isShorthand: isShorthand))
                    }
                }
                throw RuntimeError.undefinedProperty(field, loc)
            case .map(let map):
                return map[field] ?? .nil
            case .string(let str):
                // String properties
                if field == "length" { return .int(str.count) }
                throw RuntimeError.undefinedProperty(field, loc)
            case .list(let list):
                if field == "length" { return .int(list.count) }
                throw RuntimeError.undefinedProperty(field, loc)
            default:
                throw RuntimeError.undefinedProperty(field, loc)
            }

        case .assign(let target, let value, let loc):
            let val = try evaluate(value, env: env)
            switch target {
            case .identifier(let name, _):
                try env.set(name, value: val, location: loc)
                return val
            case .index(let obj, let idx, _):
                return try assignIndex(obj: obj, index: idx, value: val, env: env, loc: loc)
            case .fieldAccess(let obj, let field, _):
                return try assignField(obj: obj, field: field, value: val, env: env, loc: loc)
            default:
                throw RuntimeError.generalError("invalid assignment target", loc)
            }

        case .lambda(let params, let body, let isShorthand, _):
            return .function(Function(name: nil, params: params, body: body, closure: env, isShorthand: isShorthand))

        case .range(let start, let end, let loc):
            let startVal = try evaluate(start, env: env)
            let endVal = try evaluate(end, env: env)
            guard case .int(let s) = startVal, case .int(let e) = endVal else {
                throw RuntimeError.typeMismatch(expected: "int", got: startVal.typeName, loc)
            }
            return .list(Array(s...e).map { .int($0) })
        }
    }

    // MARK: - Binary Operations

    private func evaluateBinary(left: Expression, op: BinaryOp, right: Expression, env: Environment, loc: SourceLocation) throws -> Value {
        // Short-circuit for logical operators
        if op == .and {
            let lv = try evaluate(left, env: env)
            if !lv.isTruthy { return .bool(false) }
            let rv = try evaluate(right, env: env)
            return .bool(rv.isTruthy)
        }
        if op == .or {
            let lv = try evaluate(left, env: env)
            if lv.isTruthy { return .bool(true) }
            let rv = try evaluate(right, env: env)
            return .bool(rv.isTruthy)
        }

        let lv = try evaluate(left, env: env)
        let rv = try evaluate(right, env: env)

        switch op {
        case .add:
            switch (lv, rv) {
            case (.int(let a), .int(let b)): return .int(a + b)
            case (.float(let a), .float(let b)): return .float(a + b)
            case (.int(let a), .float(let b)): return .float(Double(a) + b)
            case (.float(let a), .int(let b)): return .float(a + Double(b))
            case (.string(let a), .string(let b)): return .string(a + b)
            case (.list(let a), .list(let b)): return .list(a + b)
            default: throw RuntimeError.typeMismatch(expected: "number or string", got: "\(lv.typeName) and \(rv.typeName)", loc)
            }
        case .subtract:
            switch (lv, rv) {
            case (.int(let a), .int(let b)): return .int(a - b)
            case (.float(let a), .float(let b)): return .float(a - b)
            case (.int(let a), .float(let b)): return .float(Double(a) - b)
            case (.float(let a), .int(let b)): return .float(a - Double(b))
            default: throw RuntimeError.typeMismatch(expected: "number", got: "\(lv.typeName) and \(rv.typeName)", loc)
            }
        case .multiply:
            switch (lv, rv) {
            case (.int(let a), .int(let b)): return .int(a * b)
            case (.float(let a), .float(let b)): return .float(a * b)
            case (.int(let a), .float(let b)): return .float(Double(a) * b)
            case (.float(let a), .int(let b)): return .float(a * Double(b))
            case (.string(let s), .int(let n)): return .string(String(repeating: s, count: max(0, n)))
            default: throw RuntimeError.typeMismatch(expected: "number", got: "\(lv.typeName) and \(rv.typeName)", loc)
            }
        case .divide:
            switch (lv, rv) {
            case (.int(let a), .int(let b)):
                guard b != 0 else { throw RuntimeError.divisionByZero(loc) }
                return .int(a / b)
            case (.float(let a), .float(let b)):
                guard b != 0 else { throw RuntimeError.divisionByZero(loc) }
                return .float(a / b)
            case (.int(let a), .float(let b)):
                guard b != 0 else { throw RuntimeError.divisionByZero(loc) }
                return .float(Double(a) / b)
            case (.float(let a), .int(let b)):
                guard b != 0 else { throw RuntimeError.divisionByZero(loc) }
                return .float(a / Double(b))
            default: throw RuntimeError.typeMismatch(expected: "number", got: "\(lv.typeName) and \(rv.typeName)", loc)
            }
        case .modulo:
            switch (lv, rv) {
            case (.int(let a), .int(let b)):
                guard b != 0 else { throw RuntimeError.divisionByZero(loc) }
                return .int(a % b)
            default: throw RuntimeError.typeMismatch(expected: "int", got: "\(lv.typeName) and \(rv.typeName)", loc)
            }
        case .equal:
            return .bool(lv == rv)
        case .notEqual:
            return .bool(lv != rv)
        case .less:
            return .bool(try compareValues(lv, rv, loc: loc) < 0)
        case .lessEqual:
            return .bool(try compareValues(lv, rv, loc: loc) <= 0)
        case .greater:
            return .bool(try compareValues(lv, rv, loc: loc) > 0)
        case .greaterEqual:
            return .bool(try compareValues(lv, rv, loc: loc) >= 0)
        case .and, .or:
            fatalError("unreachable — handled above")
        }
    }

    private func compareValues(_ lv: Value, _ rv: Value, loc: SourceLocation) throws -> Int {
        switch (lv, rv) {
        case (.int(let a), .int(let b)):
            return a < b ? -1 : (a > b ? 1 : 0)
        case (.float(let a), .float(let b)):
            return a < b ? -1 : (a > b ? 1 : 0)
        case (.int(let a), .float(let b)):
            return Double(a) < b ? -1 : (Double(a) > b ? 1 : 0)
        case (.float(let a), .int(let b)):
            return a < Double(b) ? -1 : (a > Double(b) ? 1 : 0)
        case (.string(let a), .string(let b)):
            return a < b ? -1 : (a > b ? 1 : 0)
        default:
            throw RuntimeError.typeMismatch(expected: "comparable", got: "\(lv.typeName) and \(rv.typeName)", loc)
        }
    }

    // MARK: - Function Calls

    public func callFunction(_ fn: Value, args: [Value], namedArgs: [String: Value], loc: SourceLocation?) throws -> Value {
        switch fn {
        case .function(let f):
            let callEnv = Environment(parent: f.closure)
            // Bind parameters
            for (i, param) in f.params.enumerated() {
                if let namedVal = namedArgs[param.name] {
                    callEnv.define(param.name, value: namedVal, isMutable: false)
                } else if i < args.count {
                    callEnv.define(param.name, value: args[i], isMutable: false)
                } else if let defaultExpr = param.defaultValue {
                    let val = try evaluate(defaultExpr, env: callEnv)
                    callEnv.define(param.name, value: val, isMutable: false)
                } else {
                    throw RuntimeError.arityMismatch(expected: f.params.count, got: args.count, loc)
                }
            }

            if f.isShorthand {
                // Single expression shorthand
                guard let firstStmt = f.body.first, case .expression(let expr) = firstStmt else {
                    return .nil
                }
                return try evaluate(expr, env: callEnv)
            }

            do {
                for stmt in f.body {
                    try executeStatement(stmt, env: callEnv)
                }
            } catch RuntimeError.returnValue(let value) {
                return value
            }
            return .nil

        case .builtInFunction(let f):
            // Merge named args into positional for built-ins
            var allArgs = args
            if !namedArgs.isEmpty {
                // For built-ins like ask(), pass named args as a map at the end
                if !namedArgs.isEmpty {
                    var map = OrderedMap()
                    for (k, v) in namedArgs {
                        map[k] = v
                    }
                    // Check if the last positional arg is already a map (merge)
                    allArgs.append(.map(map))
                }
            }
            return try f.body(allArgs, loc)

        case .structDef(let def):
            return try constructStruct(def: def, args: args, namedArgs: namedArgs, loc: loc)

        default:
            throw RuntimeError.notCallable(fn.typeName, loc)
        }
    }

    // MARK: - Struct Construction

    private func constructStruct(def: StructDef, args: [Value], namedArgs: [String: Value], loc: SourceLocation?) throws -> Value {
        var fields: [String: Value] = [:]

        if !namedArgs.isEmpty {
            for name in def.fields {
                if let val = namedArgs[name] {
                    fields[name] = val
                } else {
                    fields[name] = .nil
                }
            }
        } else {
            for (i, name) in def.fields.enumerated() {
                if i < args.count {
                    fields[name] = args[i]
                } else {
                    fields[name] = .nil
                }
            }
        }

        return .structInstance(StructInstance(def: def, fields: fields))
    }

    // MARK: - Method Calls

    private func callMethod(obj: Expression, method: String, args: [CallArgument], env: Environment, loc: SourceLocation) throws -> Value {
        let objVal = try evaluate(obj, env: env)

        // Evaluate args
        var positional: [Value] = []
        var named: [String: Value] = [:]
        for arg in args {
            let val = try evaluate(arg.value, env: env)
            if let label = arg.label {
                named[label] = val
            } else {
                positional.append(val)
            }
        }

        if case .structInstance(let inst) = objVal {
            if let methodStmt = inst.def.methods[method] {
                if case .fnDecl(_, let params, let body, let isShorthand, _) = methodStmt {
                    let fn = Function(name: method, params: params, body: body, closure: env, isShorthand: isShorthand)
                    let callEnv = Environment(parent: fn.closure)
                    callEnv.define("self", value: objVal, isMutable: false)
                    for (i, param) in params.enumerated() {
                        if i < positional.count {
                            callEnv.define(param.name, value: positional[i], isMutable: false)
                        }
                    }
                    if isShorthand {
                        guard let firstStmt = body.first, case .expression(let expr) = firstStmt else { return .nil }
                        return try evaluate(expr, env: callEnv)
                    }
                    do {
                        for stmt in body { try executeStatement(stmt, env: callEnv) }
                    } catch RuntimeError.returnValue(let v) { return v }
                    return .nil
                }
            }
        }

        // Built-in method dispatch for lists, strings, maps
        return try callBuiltInMethod(obj: objVal, method: method, args: positional, loc: loc)
    }

    private func callBuiltInMethod(obj: Value, method: String, args: [Value], loc: SourceLocation) throws -> Value {
        // Delegate to StandardLib methods
        return try StandardLib.callMethod(on: obj, method: method, args: args, loc: loc)
    }

    // MARK: - Pattern Matching

    private func executeMatch(value: Value, cases: [MatchCase], env: Environment, loc: SourceLocation) throws {
        for matchCase in cases {
            let scope = Environment(parent: env)
            if try matchPattern(matchCase.pattern, value: value, env: scope) {
                for stmt in matchCase.body {
                    try executeStatement(stmt, env: scope)
                }
                return
            }
        }
    }

    private func matchPattern(_ pattern: Pattern, value: Value, env: Environment) throws -> Bool {
        switch pattern {
        case .literal(let expr):
            let patternVal = try evaluate(expr, env: env)
            return patternVal == value

        case .range(let startExpr, let endExpr):
            let startVal = try evaluate(startExpr, env: env)
            let endVal = try evaluate(endExpr, env: env)
            guard case .int(let v) = value,
                  case .int(let s) = startVal,
                  case .int(let e) = endVal else {
                return false
            }
            return v >= s && v <= e

        case .variable(let name, _):
            // Always matches — binds value to name
            env.define(name, value: value, isMutable: false)
            return true
        }
    }

    // MARK: - Assignment Helpers

    private func assignIndex(obj: Expression, index: Expression, value: Value, env: Environment, loc: SourceLocation) throws -> Value {
        let objVal = try evaluate(obj, env: env)
        let idxVal = try evaluate(index, env: env)

        switch (objVal, idxVal) {
        case (.list(var list), .int(let i)):
            let idx = i < 0 ? list.count + i : i
            guard idx >= 0 && idx < list.count else {
                throw RuntimeError.indexOutOfBounds(i, count: list.count, loc)
            }
            list[idx] = value
            // Write back
            if case .identifier(let name, _) = obj {
                try env.set(name, value: .list(list), location: loc)
            }
            return value
        case (.map(var map), .string(let key)):
            map[key] = value
            if case .identifier(let name, _) = obj {
                try env.set(name, value: .map(map), location: loc)
            }
            return value
        default:
            throw RuntimeError.typeMismatch(expected: "indexable", got: objVal.typeName, loc)
        }
    }

    private func assignField(obj: Expression, field: String, value: Value, env: Environment, loc: SourceLocation) throws -> Value {
        let objVal = try evaluate(obj, env: env)
        if case .structInstance(let inst) = objVal {
            inst.fields[field] = value
            return value
        }
        throw RuntimeError.typeMismatch(expected: "struct instance", got: objVal.typeName, loc)
    }

    // MARK: - Import

    private func executeImport(path: String, alias: String?, env: Environment, loc: SourceLocation) throws {
        let resolvedPath: String
        if path.hasPrefix("/") {
            resolvedPath = path
        } else if let scriptPath = scriptPath {
            let scriptDir = (scriptPath as NSString).deletingLastPathComponent
            resolvedPath = (scriptDir as NSString).appendingPathComponent(path)
        } else {
            resolvedPath = path
        }

        guard !importedModules.contains(resolvedPath) else { return }
        importedModules.insert(resolvedPath)

        let source: String
        do {
            source = try String(contentsOfFile: resolvedPath, encoding: .utf8)
        } catch {
            throw RuntimeError.importError("could not read '\(path)': \(error.localizedDescription)", loc)
        }

        let lexer = Lexer(source: source, fileName: resolvedPath)
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens: tokens, fileName: resolvedPath)
        let stmts = try parser.parse()

        if let alias = alias {
            // Create a module namespace
            let moduleEnv = Environment(parent: globalEnv)
            for stmt in stmts {
                try executeStatement(stmt, env: moduleEnv)
            }
            // Export all definitions as a map
            // For simplicity, we load into the alias as a mini-environment
            // Users access via alias.name
            let map = OrderedMap()
            // This is a simplified approach — full module system would need more work
            env.define(alias, value: .map(map), isMutable: false)
        } else {
            // Import directly into current scope
            for stmt in stmts {
                try executeStatement(stmt, env: env)
            }
        }
    }

    // MARK: - Args Block

    private func executeArgsBlock(defs: [ArgDef], env: Environment, loc: SourceLocation) throws {
        var argIndex = 0

        for def in defs {
            switch def {
            case .positional(let name, _, _):
                if argIndex < scriptArgs.count {
                    env.define(name, value: .string(scriptArgs[argIndex]), isMutable: false)
                    argIndex += 1
                } else {
                    throw RuntimeError.generalError("missing required argument '\(name)'", loc)
                }

            case .option(let name, _, _, let defaultValue):
                let flag = "--\(name)"
                if let idx = scriptArgs.firstIndex(of: flag), idx + 1 < scriptArgs.count {
                    env.define(name, value: .string(scriptArgs[idx + 1]), isMutable: false)
                } else if let defaultExpr = defaultValue {
                    let val = try evaluate(defaultExpr, env: env)
                    env.define(name, value: val, isMutable: false)
                } else {
                    env.define(name, value: .nil, isMutable: false)
                }

            case .flag(let name, _, let short):
                let longFlag = "--\(name)"
                let shortFlag = short.map { "-\($0)" }
                let present = scriptArgs.contains(longFlag) || (shortFlag.map { scriptArgs.contains($0) } ?? false)
                env.define(name, value: .bool(present), isMutable: false)
            }
        }
    }
}
