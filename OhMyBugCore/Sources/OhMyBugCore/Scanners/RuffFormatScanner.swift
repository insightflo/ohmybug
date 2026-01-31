import Foundation

public struct RuffFormatScanner: ScannerFixer {
    public let name = "Ruff Format"
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
            "ruff format --check . 2>&1 || true",
            workingDirectory: projectPath
        )

        let output = result.stdout + result.stderr
        let unformattedFiles = output
            .components(separatedBy: "\n")
            .filter { $0.contains("Would reformat:") }
            .compactMap { line -> String? in
                let file = line.replacingOccurrences(of: "Would reformat: ", with: "").trimmingCharacters(in: .whitespaces)
                guard !file.isEmpty else { return nil }
                let skipDirs = ["__pycache__/", ".venv/", "venv/", ".tox/", "site-packages/"]
                return skipDirs.contains(where: { file.contains($0) }) ? nil : file
            }

        let issues = unformattedFiles.map { file in
            Issue(
                rule: "formatting",
                message: "File is not formatted",
                severity: .low,
                filePath: file.hasPrefix("/") ? file : "\(projectPath)/\(file)",
                scanner: name
            )
        }

        return ScanResult(
            scanner: name,
            issues: issues,
            fixedCount: 0,
            scannedFiles: unformattedFiles.count,
            duration: Date().timeIntervalSince(start)
        )
    }

    public func fix(projectPath: String) async throws -> FixResult {
        let start = Date()

        guard ProjectDetector.isPythonProject(at: projectPath) else {
            return FixResult(tool: name, totalFiles: 0, fixedFiles: 0, fixedIssueCount: 0, duration: 0)
        }

        let beforeResult = try await ShellRunner.runShell(
            "ruff format --check . 2>&1 || true",
            workingDirectory: projectPath
        )
        let beforeCount = countUnformatted(beforeResult.stdout + beforeResult.stderr)

        let _ = try await ShellRunner.runShell(
            "ruff format . 2>&1 || true",
            workingDirectory: projectPath
        )

        let afterResult = try await ShellRunner.runShell(
            "ruff format --check . 2>&1 || true",
            workingDirectory: projectPath
        )
        let afterCount = countUnformatted(afterResult.stdout + afterResult.stderr)

        let fixedCount = beforeCount - afterCount

        return FixResult(
            tool: name,
            totalFiles: beforeCount,
            fixedFiles: max(0, fixedCount),
            fixedIssueCount: max(0, fixedCount),
            duration: Date().timeIntervalSince(start)
        )
    }

    private func countUnformatted(_ output: String) -> Int {
        output.components(separatedBy: "\n")
            .filter { $0.contains("Would reformat:") }
            .count
    }
}
