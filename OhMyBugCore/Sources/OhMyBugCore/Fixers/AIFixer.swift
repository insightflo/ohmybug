import Foundation

public struct AIFixer: Fixer, Sendable {
    public let name = "AI Auto-Fix"
    private let llmConfig: LLMConfig
    private let maxIssuesPerRun: Int

    public init(llmConfig: LLMConfig, maxIssuesPerRun: Int = 20) {
        self.llmConfig = llmConfig
        self.maxIssuesPerRun = maxIssuesPerRun
    }

    public func isAvailable() async -> Bool {
        !llmConfig.apiKey.isEmpty
    }

    public func fix(projectPath: String) async throws -> FixResult {
        let start = Date()
        let client = LLMClient(config: llmConfig)

        let swiftLint = SwiftLintScanner()
        let scanResult = try await swiftLint.scan(projectPath: projectPath)

        let issuesToFix = prioritizeIssues(scanResult.issues)
            .prefix(maxIssuesPerRun)

        let groupedByFile = Dictionary(grouping: issuesToFix, by: \.filePath)
        var fixedFiles = 0
        var fixedIssueCount = 0

        for (filePath, issues) in groupedByFile {
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                continue
            }

            guard let primaryIssue = issues.first else { continue }

            do {
                let fixedContent = try await client.requestFix(issue: primaryIssue, fileContent: content)
                guard fixedContent != content, !fixedContent.isEmpty else { continue }
                try fixedContent.write(toFile: filePath, atomically: true, encoding: .utf8)
                fixedFiles += 1
                fixedIssueCount += issues.count
            } catch {
                continue
            }
        }

        return FixResult(
            tool: name,
            totalFiles: groupedByFile.count,
            fixedFiles: fixedFiles,
            fixedIssueCount: fixedIssueCount,
            duration: Date().timeIntervalSince(start)
        )
    }

    private func prioritizeIssues(_ issues: [Issue]) -> [Issue] {
        issues.sorted { $0.severity > $1.severity }
            .filter { !$0.isFixed }
    }
}
