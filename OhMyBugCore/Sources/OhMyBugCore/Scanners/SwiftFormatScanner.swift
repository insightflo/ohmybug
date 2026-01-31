import Foundation

public struct SwiftFormatScanner: ScannerFixer {
    public let name = "SwiftFormat"
    public let supportedProjectTypes: [ProjectType] = [.swift, .mixed]

    public init() {}

    public func isAvailable() async -> Bool {
        #if os(Windows)
        return false
        #else
        return await ToolInstaller.isInstalled("swiftformat")
        #endif
    }

    public func scan(projectPath: String) async throws -> ScanResult {
        let start = Date()
        let toolPath = try await ToolInstaller.ensureAvailable("swiftformat")

        let result = try await ShellRunner.run(
            toolPath,
            arguments: ["--lint", projectPath],
            workingDirectory: projectPath
        )

        let output = result.stderr + result.stdout
        let issues = parseOutput(output, projectPath: projectPath)
        let swiftFiles = ProjectDetector.findSwiftFiles(at: projectPath)

        return ScanResult(
            scanner: name,
            issues: issues,
            fixedCount: 0,
            scannedFiles: swiftFiles.count,
            duration: Date().timeIntervalSince(start)
        )
    }

    public func fix(projectPath: String) async throws -> FixResult {
        let start = Date()
        let toolPath = try await ToolInstaller.ensureAvailable("swiftformat")

        let beforeResult = try await ShellRunner.run(
            toolPath,
            arguments: ["--lint", projectPath],
            workingDirectory: projectPath
        )
        let beforeIssues = parseOutput(beforeResult.stderr + beforeResult.stdout, projectPath: projectPath)

        let formatResult = try await ShellRunner.run(
            toolPath,
            arguments: [projectPath],
            workingDirectory: projectPath
        )

        let afterResult = try await ShellRunner.run(
            toolPath,
            arguments: ["--lint", projectPath],
            workingDirectory: projectPath
        )
        let afterIssues = parseOutput(afterResult.stderr + afterResult.stdout, projectPath: projectPath)

        let fixedCount = beforeIssues.count - afterIssues.count
        let swiftFiles = ProjectDetector.findSwiftFiles(at: projectPath)

        let linesChanged = formatResult.stdout
            .components(separatedBy: "\n")
            .filter { $0.contains("was") }
            .count

        return FixResult(
            tool: name,
            totalFiles: swiftFiles.count,
            fixedFiles: linesChanged,
            fixedIssueCount: max(0, fixedCount),
            duration: Date().timeIntervalSince(start)
        )
    }

    private func parseOutput(_ output: String, projectPath _: String) -> [Issue] {
        let lines = output.components(separatedBy: "\n")
        var issues: [Issue] = []

        let pattern = #"(.+):(\d+):\d*:?\s*(?:warning|error):\s*\((\w+)\)\s*(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range) else { continue }

            guard let fileRange = Range(match.range(at: 1), in: line),
                  let lineRange = Range(match.range(at: 2), in: line),
                  let ruleRange = Range(match.range(at: 3), in: line),
                  let msgRange = Range(match.range(at: 4), in: line) else { continue }

            issues.append(Issue(
                rule: String(line[ruleRange]),
                message: String(line[msgRange]),
                severity: .low,
                filePath: String(line[fileRange]),
                line: Int(line[lineRange]),
                scanner: name
            ))
        }
        return issues
    }
}
