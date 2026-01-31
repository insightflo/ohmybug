import Foundation

public struct FlutterAnalyzerScanner: Scanner, Sendable {
    public let name = "Flutter Analyzer"
    public let supportedProjectTypes: [ProjectType] = [.flutter]

    public init() {}

    public func isAvailable() async -> Bool {
        await ToolInstaller.isInstalled("flutter")
    }

    public func scan(projectPath: String) async throws -> ScanResult {
        let start = Date()

        let result = try await ShellRunner.runShell(
            "flutter analyze --no-pub 2>&1 || true",
            workingDirectory: projectPath
        )

        let output = result.stdout + result.stderr
        let issues = parseOutput(output, projectPath: projectPath)
        let dartFiles = ProjectDetector.findDartFiles(at: projectPath)

        return ScanResult(
            scanner: name,
            issues: issues,
            fixedCount: 0,
            scannedFiles: dartFiles.count,
            duration: Date().timeIntervalSince(start)
        )
    }

    private func parseOutput(_ output: String, projectPath: String) -> [Issue] {
        let lines = output.components(separatedBy: "\n")
        var issues: [Issue] = []

        let pattern = #"^\s*(info|warning|error)\s+•\s+(.+?)\s+•\s+(.+?):(\d+):(\d+)\s+•\s+(\S+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range) else { continue }

            guard let sevRange = Range(match.range(at: 1), in: line),
                  let msgRange = Range(match.range(at: 2), in: line),
                  let fileRange = Range(match.range(at: 3), in: line),
                  let lineRange = Range(match.range(at: 4), in: line),
                  let colRange = Range(match.range(at: 5), in: line),
                  let ruleRange = Range(match.range(at: 6), in: line) else { continue }

            let sevStr = String(line[sevRange])
            let severity: Severity
            switch sevStr {
            case "error": severity = .high
            case "warning": severity = .medium
            default: severity = .low
            }

            let filePath = String(line[fileRange])
            let fullPath = filePath.hasPrefix("/") ? filePath : "\(projectPath)/\(filePath)"

            issues.append(Issue(
                rule: String(line[ruleRange]),
                message: String(line[msgRange]),
                severity: severity,
                filePath: fullPath,
                line: Int(line[lineRange]),
                column: Int(line[colRange]),
                scanner: name
            ))
        }
        return issues
    }
}
