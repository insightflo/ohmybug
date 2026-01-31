import Foundation

public struct DartFormatScanner: ScannerFixer {
    public let name = "Dart Format"
    public let supportedProjectTypes: [ProjectType] = [.flutter, .mixed]

    public init() {}

    public func isAvailable() async -> Bool {
        await ToolInstaller.isInstalled("dart")
    }

    public func scan(projectPath: String) async throws -> ScanResult {
        let start = Date()

        let result = try await ShellRunner.runShell(
            "dart format --output=none --set-exit-if-changed . 2>&1 || true",
            workingDirectory: projectPath
        )

        let output = result.stdout + result.stderr
        let unformatted = parseUnformattedFiles(output, projectPath: projectPath)
        let dartFiles = ProjectDetector.findDartFiles(at: projectPath)

        return ScanResult(
            scanner: name,
            issues: unformatted,
            fixedCount: 0,
            scannedFiles: dartFiles.count,
            duration: Date().timeIntervalSince(start)
        )
    }

    public func fix(projectPath: String) async throws -> FixResult {
        let start = Date()

        let beforeResult = try await ShellRunner.runShell(
            "dart format --output=none --set-exit-if-changed . 2>&1 || true",
            workingDirectory: projectPath
        )
        let beforeCount = countUnformatted(beforeResult.stdout + beforeResult.stderr)

        let formatResult = try await ShellRunner.runShell(
            "dart format . 2>&1",
            workingDirectory: projectPath
        )

        let afterResult = try await ShellRunner.runShell(
            "dart format --output=none --set-exit-if-changed . 2>&1 || true",
            workingDirectory: projectPath
        )
        let afterCount = countUnformatted(afterResult.stdout + afterResult.stderr)

        let changedFiles = formatResult.stdout
            .components(separatedBy: "\n")
            .filter { $0.contains("Formatted") }
            .count

        let dartFiles = ProjectDetector.findDartFiles(at: projectPath)

        return FixResult(
            tool: name,
            totalFiles: dartFiles.count,
            fixedFiles: changedFiles,
            fixedIssueCount: max(0, beforeCount - afterCount),
            duration: Date().timeIntervalSince(start)
        )
    }

    private func parseUnformattedFiles(_ output: String, projectPath: String) -> [Issue] {
        output.components(separatedBy: "\n")
            .filter { $0.hasSuffix(".dart") && !$0.contains("Formatted") && !$0.contains("Unchanged") }
            .compactMap { line -> Issue? in
                let path = line.trimmingCharacters(in: .whitespaces)
                guard !path.isEmpty else { return nil }
                return Issue(
                    rule: "formatting",
                    message: "File needs formatting",
                    severity: .low,
                    filePath: path.hasPrefix("/") ? path : "\(projectPath)/\(path)",
                    scanner: name
                )
            }
    }

    private func countUnformatted(_ output: String) -> Int {
        output.components(separatedBy: "\n")
            .filter { $0.hasSuffix(".dart") && !$0.contains("Formatted") && !$0.contains("Unchanged") }
            .count
    }
}
