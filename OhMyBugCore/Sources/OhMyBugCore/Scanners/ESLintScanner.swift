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
        var allIssues: [Issue] = []

        let frameworkInfos = FrameworkDetector.detectWithVersions(at: projectPath)
        let hasConfig = FrameworkDetector.hasESLintConfig(at: projectPath)

        allIssues.append(contentsOf: checkSetup(projectPath: projectPath, frameworkInfos: frameworkInfos, hasConfig: hasConfig))

        let hasNodeModules = FileManager.default.fileExists(atPath: "\(projectPath)/node_modules")
        guard hasNodeModules else {
            allIssues.append(Issue(
                rule: "setup/node-modules",
                message: "node_modules not found. Run 'npm install' first.",
                severity: .high,
                filePath: projectPath,
                scanner: name
            ))
            return ScanResult(
                scanner: name,
                issues: allIssues,
                fixedCount: 0,
                scannedFiles: 0,
                duration: Date().timeIntervalSince(start)
            )
        }

        let result = try await ShellRunner.runShell(
            "npx eslint . --format json 2>/dev/null || true",
            workingDirectory: projectPath
        )

        let eslintIssues = parseOutput(result.stdout)
        allIssues.append(contentsOf: eslintIssues)

        let fileCount = Set(eslintIssues.map { $0.filePath }).count

        return ScanResult(
            scanner: name,
            issues: allIssues,
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

    private func checkSetup(projectPath: String, frameworkInfos: [FrameworkInfo], hasConfig: Bool) -> [Issue] {
        var issues: [Issue] = []

        let detectedFrameworks = frameworkInfos.filter { $0.framework != .vanilla }
        guard !detectedFrameworks.isEmpty else { return [] }

        let frameworkNames = detectedFrameworks.map(\.displayName).joined(separator: ", ")

        if !hasConfig {
            var configSuggestion = "Create eslint.config.js with: "
            let configs = detectedFrameworks.compactMap(\.eslintConfig)
            configSuggestion += configs.joined(separator: ", ")

            issues.append(Issue(
                rule: "setup/missing-config",
                message: "No ESLint config found. Detected: \(frameworkNames). \(configSuggestion)",
                severity: .medium,
                filePath: projectPath,
                scanner: name
            ))
        }

        for info in detectedFrameworks {
            if !FrameworkDetector.hasRequiredPlugins(at: projectPath, for: info) {
                let plugins = info.eslintPlugins.joined(separator: " ")
                var message = "\(info.displayName) detected but ESLint plugins missing."

                if info.framework == .vue {
                    if let major = info.majorVersion {
                        message += " Use \(major >= 3 ? "plugin:vue/vue3-recommended" : "plugin:vue/recommended") in config."
                    }
                }

                message += " Run: npm install -D \(plugins)"

                issues.append(Issue(
                    rule: "setup/missing-plugins",
                    message: message,
                    severity: .medium,
                    filePath: projectPath,
                    scanner: name
                ))
            }
        }

        return issues
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
