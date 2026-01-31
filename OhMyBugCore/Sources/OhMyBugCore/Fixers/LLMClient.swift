import Foundation

public struct LLMConfig: Sendable {
    public static let glmEndpoint = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
    public static let glmModel = "codegeex-4"

    public let endpoint: String
    public let apiKey: String
    public let model: String

    public init(apiKey: String) {
        endpoint = Self.glmEndpoint
        self.apiKey = apiKey
        model = Self.glmModel
    }
}

public struct LLMClient: Sendable {
    private let config: LLMConfig

    public init(config: LLMConfig) {
        self.config = config
    }

    public func requestFix(issue: Issue, fileContent: String) async throws -> String {
        let prompt = buildPrompt(issue: issue, fileContent: fileContent)

        guard let url = URL(string: config.endpoint) else {
            throw LLMError.invalidEndpoint(config.endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt],
            ],
            "temperature": 0.1,
            "max_tokens": 4096,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.apiError(status: httpResponse.statusCode, message: errorBody)
        }

        return try extractContent(from: data)
    }

    private var systemPrompt: String {
        """
        You are a code quality fixer. Given a lint/build issue and the file content, \
        return ONLY the corrected file content. No explanations, no markdown fences, \
        just the complete corrected file.
        """
    }

    private func buildPrompt(issue: Issue, fileContent: String) -> String {
        var prompt = "Fix this issue in the file:\n\n"
        prompt += "Rule: \(issue.rule)\n"
        prompt += "Message: \(issue.message)\n"
        prompt += "File: \(issue.filePath)\n"
        if let line = issue.line {
            prompt += "Line: \(line)\n"
        }
        prompt += "\nFile content:\n\(fileContent)"
        return prompt
    }

    private func extractContent(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw LLMError.parseError
        }
        return content
    }
}

public enum LLMError: LocalizedError {
    case invalidEndpoint(String)
    case invalidResponse
    case apiError(status: Int, message: String)
    case parseError
    case noFixGenerated

    public var errorDescription: String? {
        switch self {
        case let .invalidEndpoint(url): "Invalid LLM endpoint: \(url)"
        case .invalidResponse: "Invalid response from LLM API"
        case let .apiError(status, message): "LLM API error (\(status)): \(message)"
        case .parseError: "Failed to parse LLM response"
        case .noFixGenerated: "LLM did not generate a fix"
        }
    }
}
