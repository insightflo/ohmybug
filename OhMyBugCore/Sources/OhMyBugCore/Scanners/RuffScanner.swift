import Foundation

public struct RuffScanner: ScannerFixer {
    public let name = "Ruff"
    public let supportedProjectTypes: [ProjectType] = [.python, .mixed]

    public init() {}

    public func isAvailable() async -> Bool {
        await ToolInstaller.isInstalled("ruff")
    }

    public func scan(projectPath: String) async throws -> ScanResult {
        let start = Date()

        guard ProjectDetector.isPythonProject(at: projectPath) else {
            return ScanResult(scanner: name, issues: [], fixedCount: 0, scannedFiles: 0, duration: 0)
        }

        let result = try await ShellRunner.runShell(
            "ruff check --output-format json . 2>/dev/null || true",
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

        guard ProjectDetector.isPythonProject(at: projectPath) else {
            return FixResult(tool: name, totalFiles: 0, fixedFiles: 0, fixedIssueCount: 0, duration: 0)
        }

        let beforeResult = try await ShellRunner.runShell(
            "ruff check --output-format json . 2>/dev/null || true",
            workingDirectory: projectPath
        )
        let beforeIssues = parseOutput(beforeResult.stdout, projectPath: projectPath)

        let _ = try await ShellRunner.runShell(
            "ruff check --fix . 2>/dev/null || true",
            workingDirectory: projectPath
        )

        let afterResult = try await ShellRunner.runShell(
            "ruff check --output-format json . 2>/dev/null || true",
            workingDirectory: projectPath
        )
        let afterIssues = parseOutput(afterResult.stdout, projectPath: projectPath)

        let fixedCount = beforeIssues.count - afterIssues.count
        let pyFiles = ProjectDetector.findPythonFiles(at: projectPath)

        return FixResult(
            tool: name,
            totalFiles: pyFiles.count,
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

    private func parseOutput(_ json: String, projectPath: String) -> [Issue] {
        guard let data = json.data(using: .utf8),
              let results = try? JSONDecoder().decode([RuffDiagnostic].self, from: data)
        else {
            return []
        }

        return results.map { diag in
            Issue(
                rule: diag.code ?? "unknown",
                message: diag.message,
                severity: mapSeverity(diag.code),
                filePath: diag.filename,
                line: diag.location.row,
                column: diag.location.column,
                scanner: name
            )
        }
    }

    private func mapSeverity(_ code: String?) -> Severity {
        guard let code = code else { return .medium }

        if code.hasPrefix("E") || code.hasPrefix("F") {
            return .high
        } else if code.hasPrefix("W") {
            return .medium
        } else if code.hasPrefix("C") || code.hasPrefix("N") {
            return .low
        }
        return .medium
    }
}

private struct RuffDiagnostic: Decodable {
    let code: String?
    let message: String
    let filename: String
    let location: RuffLocation
}

private struct RuffLocation: Decodable {
    let row: Int
    let column: Int
}
