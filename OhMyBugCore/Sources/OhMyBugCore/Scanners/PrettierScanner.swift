import Foundation

public struct PrettierScanner: ScannerFixer {
    public let name = "Prettier"
    public let supportedProjectTypes: [ProjectType] = [.javascript, .mixed]

    public init() {}

    public func isAvailable() async -> Bool {
        await ToolInstaller.isInstalled("npx")
    }

    public func scan(projectPath: String) async throws -> ScanResult {
        let start = Date()

        let result = try await ShellRunner.runShell(
            "npx prettier --check --ignore-path .gitignore '**/*.{js,jsx,ts,tsx,json,css}' 2>&1 || true",
            workingDirectory: projectPath
        )

        let output = result.stdout + result.stderr
        let unformattedFiles = output
            .components(separatedBy: "\n")
            .filter { $0.contains("[warn]") && !$0.contains("Code style") }
            .compactMap { line -> String? in
                let trimmed = line.replacingOccurrences(of: "[warn] ", with: "").trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                let skipDirs = [".build/", "node_modules/", ".dart_tool/", "DerivedData/", "Pods/"]
                return skipDirs.contains(where: { trimmed.contains($0) }) ? nil : trimmed
            }

        let issues = unformattedFiles.map { file in
            Issue(
                rule: "formatting",
                message: "File is not formatted",
                severity: .low,
                filePath: "\(projectPath)/\(file)",
                scanner: name
            )
        }

        let uniqueFiles = Set(issues.map(\.filePath))

        return ScanResult(
            scanner: name,
            issues: issues,
            fixedCount: 0,
            scannedFiles: uniqueFiles.count,
            duration: Date().timeIntervalSince(start)
        )
    }

    public func fix(projectPath: String) async throws -> FixResult {
        let start = Date()
        let prettierGlob = "--ignore-path .gitignore '**/*.{js,jsx,ts,tsx,json,css}'"

        let beforeResult = try await ShellRunner.runShell(
            "npx prettier --check \(prettierGlob) 2>&1 || true",
            workingDirectory: projectPath
        )
        let beforeCount = countUnformatted(beforeResult.stdout + beforeResult.stderr)

        let _ = try await ShellRunner.runShell(
            "npx prettier --write \(prettierGlob) 2>&1 || true",
            workingDirectory: projectPath
        )

        let afterResult = try await ShellRunner.runShell(
            "npx prettier --check \(prettierGlob) 2>&1 || true",
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
            .filter { $0.contains("[warn]") && !$0.contains("Code style") }
            .count
    }
}
