/// Runtime value type for the Claudine interpreter.
public indirect enum Value: CustomStringConvertible {
    case int(Int)
    case float(Double)
    case string(String)
    case bool(Bool)
    case `nil`
    case list([Value])
    case map(OrderedMap)
    case function(Function)
    case builtInFunction(BuiltInFunction)
    case structDef(StructDef)
    case structInstance(StructInstance)
    case error(String)

    public var description: String {
        switch self {
        case .int(let v): return "\(v)"
        case .float(let v):
            if v == v.rounded(.down) && !v.isInfinite && !v.isNaN {
                return String(format: "%.1f", v)
            }
            return "\(v)"
        case .string(let v): return v
        case .bool(let v): return "\(v)"
        case .nil: return "nil"
        case .list(let items):
            let inner = items.map { $0.inspectDescription }.joined(separator: ", ")
            return "[\(inner)]"
        case .map(let m):
            let pairs = m.pairs.map { "\($0.key): \($0.value.inspectDescription)" }.joined(separator: ", ")
            return "{\(pairs)}"
        case .function(let f): return "<fn \(f.name ?? "anonymous")>"
        case .builtInFunction(let f): return "<built-in \(f.name)>"
        case .structDef(let s): return "<struct \(s.name)>"
        case .structInstance(let inst): return inst.description
        case .error(let msg): return "Error: \(msg)"
        }
    }

    /// Description for use inside collections (strings get quoted).
    public var inspectDescription: String {
        switch self {
        case .string(let v): return "\"\(v)\""
        default: return description
        }
    }

    public var typeName: String {
        switch self {
        case .int: return "int"
        case .float: return "float"
        case .string: return "string"
        case .bool: return "bool"
        case .nil: return "nil"
        case .list: return "list"
        case .map: return "map"
        case .function, .builtInFunction: return "function"
        case .structDef: return "struct"
        case .structInstance(let inst): return inst.def.name
        case .error: return "error"
        }
    }

    public var isTruthy: Bool {
        switch self {
        case .bool(let v): return v
        case .nil: return false
        case .int(let v): return v != 0
        case .string(let v): return !v.isEmpty
        case .list(let items): return !items.isEmpty
        case .map(let m): return !m.pairs.isEmpty
        default: return true
        }
    }
}

extension Value: Equatable {
    public static func == (lhs: Value, rhs: Value) -> Bool {
        switch (lhs, rhs) {
        case (.int(let a), .int(let b)): return a == b
        case (.float(let a), .float(let b)): return a == b
        case (.int(let a), .float(let b)): return Double(a) == b
        case (.float(let a), .int(let b)): return a == Double(b)
        case (.string(let a), .string(let b)): return a == b
        case (.bool(let a), .bool(let b)): return a == b
        case (.nil, .nil): return true
        case (.list(let a), .list(let b)): return a == b
        case (.map(let a), .map(let b)): return a == b
        default: return false
        }
    }
}

/// A user-defined function.
public struct Function {
    public let name: String?
    public let params: [FunctionParam]
    public let body: [Statement]
    public let closure: Environment
    public let isShorthand: Bool // single expression => shorthand

    public init(name: String?, params: [FunctionParam], body: [Statement], closure: Environment, isShorthand: Bool = false) {
        self.name = name
        self.params = params
        self.body = body
        self.closure = closure
        self.isShorthand = isShorthand
    }
}

/// A function parameter.
public struct FunctionParam: Equatable {
    public let name: String
    public let defaultValue: Expression?

    public init(name: String, defaultValue: Expression? = nil) {
        self.name = name
        self.defaultValue = defaultValue
    }
}

/// A built-in (native) function.
public struct BuiltInFunction {
    public let name: String
    public let arity: Int? // nil means variadic
    public let body: ([Value], SourceLocation?) throws -> Value

    public init(name: String, arity: Int?, body: @escaping ([Value], SourceLocation?) throws -> Value) {
        self.name = name
        self.arity = arity
        self.body = body
    }
}

/// A struct definition.
public struct StructDef: Equatable {
    public let name: String
    public let fields: [String]
    public let methods: [String: Statement] // method name -> FnDecl statement

    public init(name: String, fields: [String], methods: [String: Statement]) {
        self.name = name
        self.fields = fields
        self.methods = methods
    }

    public static func == (lhs: StructDef, rhs: StructDef) -> Bool {
        lhs.name == rhs.name && lhs.fields == rhs.fields
    }
}

/// An instance of a struct.
public class StructInstance: Equatable, CustomStringConvertible {
    public let def: StructDef
    public var fields: [String: Value]

    public init(def: StructDef, fields: [String: Value]) {
        self.def = def
        self.fields = fields
    }

    public var description: String {
        let pairs = def.fields.compactMap { name -> String? in
            guard let val = fields[name] else { return nil }
            return "\(name): \(val.inspectDescription)"
        }.joined(separator: ", ")
        return "\(def.name)(\(pairs))"
    }

    public static func == (lhs: StructInstance, rhs: StructInstance) -> Bool {
        lhs.def == rhs.def && lhs.fields.keys.allSatisfy { lhs.fields[$0] == rhs.fields[$0] }
    }
}

/// Ordered map to preserve insertion order.
public struct OrderedMap: Equatable {
    public struct Pair: Equatable {
        public let key: String
        public var value: Value

        public init(key: String, value: Value) {
            self.key = key
            self.value = value
        }
    }

    public var pairs: [Pair]

    public init(pairs: [Pair] = []) {
        self.pairs = pairs
    }

    public subscript(key: String) -> Value? {
        get { pairs.first(where: { $0.key == key })?.value }
        set {
            if let idx = pairs.firstIndex(where: { $0.key == key }) {
                if let newValue {
                    pairs[idx] = Pair(key: key, value: newValue)
                } else {
                    pairs.remove(at: idx)
                }
            } else if let newValue {
                pairs.append(Pair(key: key, value: newValue))
            }
        }
    }

    public var keys: [String] { pairs.map(\.key) }
    public var values: [Value] { pairs.map(\.value) }
    public var count: Int { pairs.count }
}
