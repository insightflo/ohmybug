import Foundation

public struct SwiftLintScanner: ScannerFixer {
    public let name = "SwiftLint"
    public let supportedProjectTypes: [ProjectType] = [.swift, .mixed]

    public init() {}

    public func isAvailable() async -> Bool {
        await ToolInstaller.isInstalled("swiftlint")
    }

    public func scan(projectPath: String) async throws -> ScanResult {
        let start = Date()
        let toolPath = try await ToolInstaller.ensureAvailable("swiftlint")

        let result = try await ShellRunner.runShell(
            "\(toolPath) lint --reporter json --quiet --exclude .build --exclude DerivedData --exclude Pods --exclude .dart_tool",
            workingDirectory: projectPath
        )

        let issues = parseOutput(result.stdout, projectPath: projectPath)
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
        let toolPath = try await ToolInstaller.ensureAvailable("swiftlint")

        let excludeArgs = "--exclude .build --exclude DerivedData --exclude Pods --exclude .dart_tool"

        let beforeResult = try await ShellRunner.runShell(
            "\(toolPath) lint --reporter json --quiet \(excludeArgs)",
            workingDirectory: projectPath
        )
        let beforeIssues = parseOutput(beforeResult.stdout, projectPath: projectPath)

        let _ = try await ShellRunner.runShell(
            "\(toolPath) lint --fix --quiet \(excludeArgs)",
            workingDirectory: projectPath
        )

        let afterResult = try await ShellRunner.runShell(
            "\(toolPath) lint --reporter json --quiet \(excludeArgs)",
            workingDirectory: projectPath
        )
        let afterIssues = parseOutput(afterResult.stdout, projectPath: projectPath)

        let fixedCount = beforeIssues.count - afterIssues.count
        let totalFiles = Set(beforeIssues.map { $0.filePath }).count
        let fixedFiles = Set(
            beforeIssues.map(\.filePath)
                .filter { file in
                    let beforeCount = beforeIssues.filter { $0.filePath == file }.count
                    let afterCount = afterIssues.filter { $0.filePath == file }.count
                    return afterCount < beforeCount
                }
        ).count

        return FixResult(
            tool: name,
            totalFiles: totalFiles,
            fixedFiles: fixedFiles,
            fixedIssueCount: max(0, fixedCount),
            duration: Date().timeIntervalSince(start)
        )
    }

    private func parseOutput(_ json: String, projectPath _: String) -> [Issue] {
        guard let data = json.data(using: .utf8),
              let entries = try? JSONDecoder().decode([SwiftLintEntry].self, from: data)
        else {
            return []
        }

        return entries.map { entry in
            Issue(
                rule: entry.rule_id,
                message: entry.reason,
                severity: entry.severity == "error" ? .high : .medium,
                filePath: entry.file,
                line: entry.line,
                column: entry.character,
                scanner: name
            )
        }
    }
}

private struct SwiftLintEntry: Decodable {
    let rule_id: String
    let reason: String
    let severity: String
    let file: String
    let line: Int
    let character: Int?
}
