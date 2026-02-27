import Foundation

/// AI integration (Claude API) built-in functions for Claudine.
public struct AILib {
    public static func register(in env: Environment) {
        env.define("ask", value: .builtInFunction(BuiltInFunction(name: "ask", arity: nil) { args, loc in
            guard !args.isEmpty else {
                throw RuntimeError.arityMismatch(expected: 1, got: 0, loc)
            }
            guard case .string(let prompt) = args[0] else {
                throw RuntimeError.typeMismatch(expected: "string", got: args[0].typeName, loc)
            }

            // Extract options from named args (passed as map)
            var model = "sonnet"
            var temperature: Double? = nil
            var systemPrompt: String? = nil
            var format: OrderedMap? = nil

            // Check if there's a map of options (from named args)
            for arg in args.dropFirst() {
                if case .map(let opts) = arg {
                    if case .string(let m) = opts["model"] { model = m }
                    if case .float(let t) = opts["temperature"] { temperature = t }
                    if case .string(let s) = opts["system"] { systemPrompt = s }
                    if case .map(let f) = opts["format"] { format = f }
                }
            }

            // Get API key
            guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
                throw RuntimeError.networkError(
                    "ANTHROPIC_API_KEY environment variable not set. Set it with: export ANTHROPIC_API_KEY=your-key",
                    loc
                )
            }

            return try callClaudeAPI(
                prompt: prompt,
                model: model,
                temperature: temperature,
                systemPrompt: systemPrompt,
                format: format,
                apiKey: apiKey,
                loc: loc
            )
        }), isMutable: false)
    }

    private static func callClaudeAPI(
        prompt: String,
        model: String,
        temperature: Double?,
        systemPrompt: String?,
        format: OrderedMap?,
        apiKey: String,
        loc: SourceLocation?
    ) throws -> Value {
        let modelId = resolveModel(model)

        // Build request
        let messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]

        var body: [String: Any] = [
            "model": modelId,
            "max_tokens": 4096,
            "messages": messages,
        ]

        if let temp = temperature {
            body["temperature"] = temp
        }

        if let sys = systemPrompt {
            body["system"] = sys
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw RuntimeError.networkError("invalid API URL", loc)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData

        // Synchronous HTTP call
        var responseData: Data?
        var responseError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            responseData = data
            responseError = error
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = responseError {
            throw RuntimeError.networkError(error.localizedDescription, loc)
        }

        guard let data = responseData else {
            throw RuntimeError.networkError("no response data", loc)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RuntimeError.networkError("invalid JSON response", loc)
        }

        // Check for API errors
        if let errorInfo = json["error"] as? [String: Any],
           let message = errorInfo["message"] as? String {
            throw RuntimeError.networkError("API error: \(message)", loc)
        }

        // Extract text from response
        guard let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw RuntimeError.networkError("unexpected response format", loc)
        }

        // If format was specified, try to parse as JSON and return a map
        if let format = format {
            return parseStructuredResponse(text: text, format: format, loc: loc)
        }

        return .string(text)
    }

    private static func resolveModel(_ shortName: String) -> String {
        switch shortName.lowercased() {
        case "opus": return "claude-opus-4-20250514"
        case "sonnet": return "claude-sonnet-4-20250514"
        case "haiku": return "claude-haiku-4-5-20251001"
        default: return shortName // Allow full model IDs
        }
    }

    private static func parseStructuredResponse(text: String, format: OrderedMap, loc: SourceLocation?) -> Value {
        // Try to parse JSON from the response
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Try to find JSON in the text
            if let start = text.range(of: "{"),
               let end = text.range(of: "}", options: .backwards) {
                let jsonStr = String(text[start.lowerBound...end.upperBound])
                if let data = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return jsonToValue(json)
                }
            }
            return .string(text)
        }
        return jsonToValue(json)
    }

    private static func jsonToValue(_ json: Any) -> Value {
        switch json {
        case let s as String:
            return .string(s)
        case let n as Int:
            return .int(n)
        case let n as Double:
            return .float(n)
        case let b as Bool:
            return .bool(b)
        case let arr as [Any]:
            return .list(arr.map { jsonToValue($0) })
        case let dict as [String: Any]:
            var map = OrderedMap()
            for (k, v) in dict {
                map[k] = jsonToValue(v)
            }
            return .map(map)
        default:
            return .nil
        }
    }
}
