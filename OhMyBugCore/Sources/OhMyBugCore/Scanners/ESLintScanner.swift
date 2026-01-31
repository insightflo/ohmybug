import Foundation

public struct ESLintScanner: ScannerFixer {
    public let name = "ESLint"
    public let supportedProjectTypes: [ProjectType] = [.javascript, .mixed]

    public init() {}

    public func isAvailable() async -> Bool {
        await ToolInstaller.isInstalled("npx")
    }

    public func scan(projectPath: String) async throws -> ScanResult {
        let start = Date()

        let hasLocalESLint = FileManager.default.fileExists(
            atPath: "\(projectPath)/node_modules/.bin/eslint"
        )

        let command = hasLocalESLint
            ? "npx eslint . --format json 2>/dev/null || true"
            : "npx eslint . --format json 2>/dev/null || true"

        let result = try await ShellRunner.runShell(command, workingDirectory: projectPath)
        let issues = parseOutput(result.stdout)
        let fileCount = Set(issues.map { $0.filePath }).count

        return ScanResult(
            scanner: name,
            issues: issues,
            fixedCount: 0,
            scannedFiles: fileCount,
            duration: Date().timeIntervalSince(start)
        )
    }

    public func fix(projectPath: String) async throws -> FixResult {
        let start = Date()

        let beforeResult = try await ShellRunner.runShell(
            "npx eslint . --format json 2>/dev/null || true",
            workingDirectory: projectPath
        )
        let beforeIssues = parseOutput(beforeResult.stdout)

        let _ = try await ShellRunner.runShell(
            "npx eslint . --fix 2>/dev/null || true",
            workingDirectory: projectPath
        )

        let afterResult = try await ShellRunner.runShell(
            "npx eslint . --format json 2>/dev/null || true",
            workingDirectory: projectPath
        )
        let afterIssues = parseOutput(afterResult.stdout)

        let fixedCount = beforeIssues.count - afterIssues.count
        let jsFiles = ProjectDetector.findJSFiles(at: projectPath)

        return FixResult(
            tool: name,
            totalFiles: jsFiles.count,
            fixedFiles: Set(
                beforeIssues.map(\.filePath)
                    .filter { file in
                        beforeIssues.filter { $0.filePath == file }.count >
                            afterIssues.filter { $0.filePath == file }.count
                    }
            ).count,
            fixedIssueCount: max(0, fixedCount),
            duration: Date().timeIntervalSince(start)
        )
    }

    private func parseOutput(_ json: String) -> [Issue] {
        guard let data = json.data(using: .utf8),
              let files = try? JSONDecoder().decode([ESLintFile].self, from: data)
        else {
            return []
        }

        return files.flatMap { file in
            file.messages.map { msg in
                Issue(
                    rule: msg.ruleId ?? "unknown",
                    message: msg.message,
                    severity: msg.severity >= 2 ? .high : .medium,
                    filePath: file.filePath,
                    line: msg.line,
                    column: msg.column,
                    scanner: name
                )
            }
        }
    }
}

private struct ESLintFile: Decodable {
    let filePath: String
    let messages: [ESLintMessage]
}

private struct ESLintMessage: Decodable {
    let ruleId: String?
    let message: String
    let severity: Int
    let line: Int
    let column: Int?
}
