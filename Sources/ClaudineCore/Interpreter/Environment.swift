/// Lexically scoped variable environment for Claudine.
public class Environment {
    private var values: [String: Value] = [:]
    private var mutable: Set<String> = []
    public let parent: Environment?

    public init(parent: Environment? = nil) {
        self.parent = parent
    }

    /// Define a new variable in the current scope.
    public func define(_ name: String, value: Value, isMutable: Bool) {
        values[name] = value
        if isMutable {
            mutable.insert(name)
        }
    }

    /// Look up a variable by name, searching parent scopes.
    public func get(_ name: String) throws -> Value {
        if let value = values[name] {
            return value
        }
        if let parent = parent {
            return try parent.get(name)
        }
        throw RuntimeError.undefinedVariable(name, nil)
    }

    /// Look up a variable, returning nil if not found.
    public func getOptional(_ name: String) -> Value? {
        if let value = values[name] {
            return value
        }
        return parent?.getOptional(name)
    }

    /// Assign to an existing variable (must be mutable).
    public func set(_ name: String, value: Value, location: SourceLocation? = nil) throws {
        if values.keys.contains(name) {
            guard mutable.contains(name) else {
                throw RuntimeError.immutableVariable(name, location)
            }
            values[name] = value
            return
        }
        if let parent = parent {
            try parent.set(name, value: value, location: location)
            return
        }
        throw RuntimeError.undefinedVariable(name, location)
    }

    /// Check if a variable is defined in the current scope.
    public func isDefined(_ name: String) -> Bool {
        values.keys.contains(name) || (parent?.isDefined(name) ?? false)
    }
}
