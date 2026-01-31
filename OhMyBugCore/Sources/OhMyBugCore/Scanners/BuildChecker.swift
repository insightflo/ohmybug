import Foundation

public struct BuildChecker: Scanner {
    public let name = "Build Check"
    public let supportedProjectTypes: [ProjectType] = [.swift, .flutter, .mixed]

    public init() {}

    public func isAvailable() async -> Bool {
        true
    }

    public func scan(projectPath: String) async throws -> ScanResult {
        let start = Date()
        let targets = findBuildTargets(at: projectPath)

        guard !targets.isEmpty else {
            return ScanResult(scanner: name, issues: [], fixedCount: 0, scannedFiles: 0, duration: 0)
        }

        var allIssues: [Issue] = []
        var totalFiles = 0

        for target in targets {
            let result = try await runBuild(target)
            allIssues.append(contentsOf: result.issues)
            totalFiles += result.fileCount
        }

        return ScanResult(
            scanner: name,
            issues: allIssues,
            fixedCount: 0,
            scannedFiles: totalFiles,
            duration: Date().timeIntervalSince(start)
        )
    }

    private struct BuildTarget {
        enum Kind { case spm, xcodeproj, pubspec }
        let path: String
        let kind: Kind
    }

    private struct BuildResult {
        let issues: [Issue]
        let fileCount: Int
        let succeeded: Bool
    }

    private func findBuildTargets(at rootPath: String) -> [BuildTarget] {
        let fm = FileManager.default
        var targets: [BuildTarget] = []

        #if !os(Windows)
        if fm.fileExists(atPath: "\(rootPath)/Package.swift") {
            targets.append(BuildTarget(path: rootPath, kind: .spm))
        }
        if (try? fm.contentsOfDirectory(atPath: rootPath))?.contains(where: { $0.hasSuffix(".xcodeproj") }) == true {
            targets.append(BuildTarget(path: rootPath, kind: .xcodeproj))
        }
        #endif
        if fm.fileExists(atPath: "\(rootPath)/pubspec.yaml") {
            targets.append(BuildTarget(path: rootPath, kind: .pubspec))
        }

        if !targets.isEmpty { return targets }

        let skipDirs = Set(["node_modules", ".git", ".build", "DerivedData", "build", ".dart_tool", ".pub-cache", "Pods"])
        guard let contents = try? fm.contentsOfDirectory(atPath: rootPath) else { return [] }

        for item in contents {
            guard !skipDirs.contains(item) else { continue }
            let subPath = "\(rootPath)/\(item)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: subPath, isDirectory: &isDir), isDir.boolValue else { continue }

            #if !os(Windows)
            if fm.fileExists(atPath: "\(subPath)/Package.swift") {
                targets.append(BuildTarget(path: subPath, kind: .spm))
            }
            if (try? fm.contentsOfDirectory(atPath: subPath))?.contains(where: { $0.hasSuffix(".xcodeproj") }) == true {
                targets.append(BuildTarget(path: subPath, kind: .xcodeproj))
            }
            #endif
            if fm.fileExists(atPath: "\(subPath)/pubspec.yaml") {
                targets.append(BuildTarget(path: subPath, kind: .pubspec))
            }
        }

        return targets
    }

    private func runBuild(_ target: BuildTarget) async throws -> BuildResult {
        let result: ShellOutput
        switch target.kind {
        case .pubspec:
            result = try await ShellRunner.runShell(
                "flutter analyze --no-pub 2>&1 || true",
                workingDirectory: target.path
            )
            let output = result.stdout + result.stderr
            let issues = parseDartBuildErrors(output, projectPath: target.path)
            let fileCount = ProjectDetector.findDartFiles(at: target.path).count
            return BuildResult(issues: issues, fileCount: fileCount, succeeded: result.succeeded)

        case .xcodeproj:
            result = try await ShellRunner.runShell(
                "xcodebuild -project *.xcodeproj -scheme * build 2>&1 | tail -50",
                workingDirectory: target.path
            )

        case .spm:
            result = try await ShellRunner.runShell(
                "swift build 2>&1",
                workingDirectory: target.path
            )
        }

        let output = result.stdout + result.stderr
        let issues = parseBuildErrors(output, projectPath: target.path)
        let fileCount = ProjectDetector.findSwiftFiles(at: target.path).count
        return BuildResult(issues: issues, fileCount: fileCount, succeeded: result.succeeded)
    }

    private func parseBuildErrors(_ output: String, projectPath _: String) -> [Issue] {
        let lines = output.components(separatedBy: "\n")
        var issues: [Issue] = []

        let pattern = #"(.+\.swift):(\d+):(\d+):\s*(error|warning):\s*(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range) else { continue }

            guard let fileRange = Range(match.range(at: 1), in: line),
                  let lineRange = Range(match.range(at: 2), in: line),
                  let colRange = Range(match.range(at: 3), in: line),
                  let sevRange = Range(match.range(at: 4), in: line),
                  let msgRange = Range(match.range(at: 5), in: line) else { continue }

            let sevStr = String(line[sevRange])
            issues.append(Issue(
                rule: "build_\(sevStr)",
                message: String(line[msgRange]),
                severity: sevStr == "error" ? .critical : .medium,
                filePath: String(line[fileRange]),
                line: Int(line[lineRange]),
                column: Int(line[colRange]),
                scanner: name
            ))
        }
        return issues
    }

    private func parseDartBuildErrors(_ output: String, projectPath: String) -> [Issue] {
        let lines = output.components(separatedBy: "\n")
        var issues: [Issue] = []

        let pattern = #"^\s*(error|warning)\s+•\s+(.+?)\s+•\s+(.+?):(\d+):(\d+)\s+•\s+(\S+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range) else { continue }

            guard let sevRange = Range(match.range(at: 1), in: line),
                  let msgRange = Range(match.range(at: 2), in: line),
                  let fileRange = Range(match.range(at: 3), in: line),
                  let lineRange = Range(match.range(at: 4), in: line),
                  let colRange = Range(match.range(at: 5), in: line) else { continue }

            let sevStr = String(line[sevRange])
            let filePath = String(line[fileRange])
            let fullPath = filePath.hasPrefix("/") ? filePath : "\(projectPath)/\(filePath)"

            issues.append(Issue(
                rule: "build_\(sevStr)",
                message: String(line[msgRange]),
                severity: sevStr == "error" ? .critical : .medium,
                filePath: fullPath,
                line: Int(line[lineRange]),
                column: Int(line[colRange]),
                scanner: name
            ))
        }
        return issues
    }
}
