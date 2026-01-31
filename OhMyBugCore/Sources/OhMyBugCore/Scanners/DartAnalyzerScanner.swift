import Foundation

public struct DartAnalyzerScanner: Scanner, Sendable {
    public let name = "Dart Analyzer"
    public let supportedProjectTypes: [ProjectType] = [.flutter, .mixed]

    public init() {}

    public func isAvailable() async -> Bool {
        await ToolInstaller.isInstalled("dart")
    }

    public func scan(projectPath: String) async throws -> ScanResult {
        let start = Date()

        let result = try await ShellRunner.runShell(
            "dart analyze --format=machine 2>&1 || true",
            workingDirectory: projectPath
        )

        let issues = parseOutput(result.stdout + result.stderr, projectPath: projectPath)
        let fileCount = Set(issues.map { $0.filePath }).count

        return ScanResult(
            scanner: name,
            issues: issues,
            fixedCount: 0,
            scannedFiles: fileCount,
            duration: Date().timeIntervalSince(start)
        )
    }

    private func parseOutput(_ output: String, projectPath _: String) -> [Issue] {
        let lines = output.components(separatedBy: "\n")
        var issues: [Issue] = []

        for line in lines {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 8 else { continue }

            let severityStr = parts[0].trimmingCharacters(in: .whitespaces)
            let severity: Severity
            switch severityStr {
            case "ERROR": severity = .high
            case "WARNING": severity = .medium
            case "INFO": severity = .low
            default: continue
            }

            let filePath = parts[3].trimmingCharacters(in: .whitespaces)
            let lineNum = Int(parts[4].trimmingCharacters(in: .whitespaces))
            let column = Int(parts[5].trimmingCharacters(in: .whitespaces))
            let message = parts[7].trimmingCharacters(in: .whitespaces)
            let rule = parts[2].trimmingCharacters(in: .whitespaces)

            issues.append(Issue(
                rule: rule,
                message: message,
                severity: severity,
                filePath: filePath,
                line: lineNum,
                column: column,
                scanner: name
            ))
        }
        return issues
    }
}
