import Foundation

/// File I/O built-in functions for Claudine.
public struct IOLib {
    public static func register(in env: Environment) {
        env.define("read_file", value: .builtInFunction(BuiltInFunction(name: "read_file", arity: 1) { args, loc in
            guard case .string(let path) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                return .string(content)
            } catch {
                throw RuntimeError.fileError("could not read '\(path)': \(error.localizedDescription)", loc)
            }
        }), isMutable: false)

        env.define("write_file", value: .builtInFunction(BuiltInFunction(name: "write_file", arity: 2) { args, loc in
            guard case .string(let path) = args[0], case .string(let content) = args[1] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }
            do {
                try content.write(toFile: path, atomically: true, encoding: .utf8)
                return .nil
            } catch {
                throw RuntimeError.fileError("could not write '\(path)': \(error.localizedDescription)", loc)
            }
        }), isMutable: false)

        env.define("append_file", value: .builtInFunction(BuiltInFunction(name: "append_file", arity: 2) { args, loc in
            guard case .string(let path) = args[0], case .string(let content) = args[1] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }
            do {
                if FileManager.default.fileExists(atPath: path) {
                    let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
                    handle.seekToEndOfFile()
                    if let data = content.data(using: .utf8) {
                        handle.write(data)
                    }
                    handle.closeFile()
                } else {
                    try content.write(toFile: path, atomically: true, encoding: .utf8)
                }
                return .nil
            } catch {
                throw RuntimeError.fileError("could not append to '\(path)': \(error.localizedDescription)", loc)
            }
        }), isMutable: false)

        env.define("file_exists", value: .builtInFunction(BuiltInFunction(name: "file_exists", arity: 1) { args, loc in
            guard case .string(let path) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }
            return .bool(FileManager.default.fileExists(atPath: path))
        }), isMutable: false)
    }
}
