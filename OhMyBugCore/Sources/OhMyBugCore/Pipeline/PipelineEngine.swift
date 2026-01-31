import Foundation

public protocol PipelineDelegate: AnyObject, Sendable {
    func pipelineDidChangePhase(_ phase: ScanPhase)
    func pipelineDidLog(_ entry: LogEntry)
    func pipelineDidUpdateProgress(_ progress: Double)
}

public struct ScanReport: Sendable {
    public let projectPath: String
    public let startedAt: Date
    public let completedAt: Date
    public let issues: [Issue]
    public let scanResults: [ScanResult]
    public let buildSucceeded: Bool?
    public let affectedFiles: [String]

    public var summary: IssueSummary {
        IssueSummary.from(issues: issues)
    }
}

public actor PipelineEngine {
    private let config: ProjectConfig
    private var scanners: [any Scanner] = []
    private var fixers: [any Fixer] = []
    private weak var delegate: PipelineDelegate?
    private var currentPhase: ScanPhase = .idle
    private var backupManager: BackupManager?
    private var lastScanReport: ScanReport?

    public init(config: ProjectConfig) {
        self.config = config
        backupManager = BackupManager(projectPath: config.projectPath)
    }

    public func setDelegate(_ delegate: PipelineDelegate) {
        self.delegate = delegate
    }

    public func registerScanner(_ scanner: any Scanner) {
        scanners.append(scanner)
    }

    public func registerFixer(_ fixer: any Fixer) {
        fixers.append(fixer)
    }

    public func scan() async throws -> ScanReport {
        let startedAt = Date()
        var allScanResults: [ScanResult] = []

        await setPhase(.build)
        var buildSucceeded: Bool? = nil
        if config.runBuildCheck {
            buildSucceeded = await runBuildCheck()
        }

        await setPhase(.tools)
        await ensureToolsAvailable()

        await setPhase(.scan)
        let allIssues = await runScanPhase(&allScanResults)

        let affectedFiles = Array(Set(allIssues.map(\.filePath)))

        let report = ScanReport(
            projectPath: config.projectPath,
            startedAt: startedAt,
            completedAt: Date(),
            issues: allIssues,
            scanResults: allScanResults,
            buildSucceeded: buildSucceeded,
            affectedFiles: affectedFiles
        )

        lastScanReport = report
        await setPhase(.idle)
        log(.success, "Scan complete: \(allIssues.count) issues found in \(affectedFiles.count) files")
        return report
    }

    public func fix() async throws -> PipelineReport {
        guard let scanReport = lastScanReport else {
            throw PipelineError.noScanReport
        }

        await setPhase(.aiFix)
        log(.info, "Creating backup of \(scanReport.affectedFiles.count) affected files...")
        if let backupManager {
            try await backupManager.createSnapshot(files: scanReport.affectedFiles)
            let count = await backupManager.backedUpFileCount
            log(.success, "Backup created (\(count) files)")
        }

        var allFixResults: [FixResult] = []
        await runFixPhase(&allFixResults)

        await setPhase(.scan)
        var postFixScanResults: [ScanResult] = []
        let afterIssues = await runScanPhase(&postFixScanResults)

        await setPhase(.verify)
        var buildSucceeded: Bool? = nil
        if config.runBuildCheck {
            buildSucceeded = await runBuildCheck()
            if buildSucceeded == false {
                log(.error, "Build failed after fix. Use rollback to restore.")
            }
        }

        await setPhase(.complete)

        return PipelineReport(
            projectPath: config.projectPath,
            startedAt: scanReport.startedAt,
            completedAt: Date(),
            beforeIssues: scanReport.summary,
            afterIssues: IssueSummary.from(issues: afterIssues),
            scanResults: postFixScanResults,
            fixResults: allFixResults,
            buildSucceeded: buildSucceeded
        )
    }

    public func rollback() async throws -> Int {
        guard let backupManager else {
            throw PipelineError.noBackup
        }
        guard await backupManager.snapshotExists else {
            throw PipelineError.noBackup
        }

        log(.warning, "Rolling back changes...")
        let restoredCount = try await backupManager.rollback()
        log(.success, "Rolled back \(restoredCount) files")
        await setPhase(.idle)
        return restoredCount
    }

    public func cleanupBackup() async {
        await backupManager?.cleanup()
    }

    public var canRollback: Bool {
        get async {
            guard let backupManager else { return false }
            return await backupManager.snapshotExists
        }
    }

    @available(*, deprecated, message: "Use scan() then fix() separately")
    public func run() async throws -> PipelineReport {
        let scanReport = try await scan()

        guard config.autoApplyFixes else {
            return PipelineReport(
                projectPath: config.projectPath,
                startedAt: scanReport.startedAt,
                completedAt: Date(),
                beforeIssues: scanReport.summary,
                afterIssues: scanReport.summary,
                scanResults: scanReport.scanResults,
                fixResults: [],
                buildSucceeded: scanReport.buildSucceeded
            )
        }

        return try await fix()
    }

    private func setPhase(_ phase: ScanPhase) async {
        currentPhase = phase
        delegate?.pipelineDidChangePhase(phase)
        log(.info, "Phase: \(phase.rawValue)")
    }

    private func log(_ level: LogLevel, _ message: String, source: String? = nil) {
        let entry = LogEntry(level: level, message: message, source: source)
        delegate?.pipelineDidLog(entry)
    }

    private func runBuildCheck() async -> Bool {
        let targets = findBuildDirs(at: config.projectPath)

        guard !targets.isEmpty else {
            log(.warning, "No buildable targets found")
            return true
        }

        var allSucceeded = true
        for (path, command) in targets {
            let name = (path as NSString).lastPathComponent
            log(.info, "Building \(name)...")
            do {
                let result = try await ShellRunner.runShell(command, workingDirectory: path)
                if result.succeeded {
                    log(.success, "\(name): BUILD SUCCEEDED")
                } else {
                    log(.error, "\(name): BUILD FAILED")
                    allSucceeded = false
                }
            } catch {
                log(.error, "\(name): \(error.localizedDescription)")
                allSucceeded = false
            }
        }
        return allSucceeded
    }

    private func findBuildDirs(at rootPath: String) -> [(path: String, command: String)] {
        let fm = FileManager.default
        var targets: [(String, String)] = []

        func check(_ path: String) {
            if fm.fileExists(atPath: "\(path)/pubspec.yaml") {
                targets.append((path, "flutter analyze --no-pub 2>&1"))
            } else if fm.fileExists(atPath: "\(path)/Package.swift") {
                targets.append((path, "swift build 2>&1"))
            } else if (try? fm.contentsOfDirectory(atPath: path))?.contains(where: { $0.hasSuffix(".xcodeproj") }) == true {
                targets.append((path, "xcodebuild -project *.xcodeproj -scheme * build 2>&1 | tail -50"))
            }
        }

        check(rootPath)
        if !targets.isEmpty { return targets }

        let skipDirs = Set(["node_modules", ".git", ".build", "DerivedData", "build", ".dart_tool", ".pub-cache", "Pods"])
        guard let contents = try? fm.contentsOfDirectory(atPath: rootPath) else { return targets }

        for item in contents {
            guard !skipDirs.contains(item) else { continue }
            let subPath = "\(rootPath)/\(item)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: subPath, isDirectory: &isDir), isDir.boolValue else { continue }
            check(subPath)
        }

        return targets
    }

    private func ensureToolsAvailable() async {
        for scanner in scanners {
            let available = await scanner.isAvailable()
            if available {
                log(.success, "\(scanner.name) is available")
            } else {
                log(.warning, "\(scanner.name) is not available, attempting install...")
            }
        }
    }

    private func runScanPhase(_ results: inout [ScanResult]) async -> [Issue] {
        var allIssues: [Issue] = []
        let projectType = config.projectType == .auto
            ? ProjectDetector.detect(at: config.projectPath)
            : config.projectType

        for scanner in scanners {
            let shouldRun = scanner.supportedProjectTypes.contains(projectType) ||
                (projectType == .mixed && scanner.supportedProjectTypes.contains(.mixed))
            guard shouldRun else {
                continue
            }

            log(.info, "Running \(scanner.name)...")
            do {
                let result = try await scanner.scan(projectPath: config.projectPath)
                results.append(result)
                allIssues.append(contentsOf: result.issues)
                log(.success, "\(scanner.name): \(result.totalCount) issues found in \(result.scannedFiles) files")
            } catch {
                log(.error, "\(scanner.name) failed: \(error.localizedDescription)")
            }
        }

        let filtered = filterAutoGeneratedFiles(allIssues)
        let deduplicated = deduplicateIssues(filtered)
        let adjusted = adjustSeverityForTestCode(deduplicated)
        return adjusted
    }

    private func filterAutoGeneratedFiles(_ issues: [Issue]) -> [Issue] {
        let excludePatterns = [
            "/ios_old/",
            "/worktree/",
            "GeneratedPluginRegistrant.swift",
            ".g.dart",
            ".freezed.dart",
            ".gr.dart",
            "/DerivedData/",
            "/build/",
            "/.dart_tool/",
        ]

        return issues.filter { issue in
            !excludePatterns.contains { pattern in
                issue.filePath.contains(pattern)
            }
        }
    }

    private func deduplicateIssues(_ issues: [Issue]) -> [Issue] {
        var seen = Set<String>()
        var unique: [Issue] = []

        let priorityOrder: [Severity] = [.critical, .high, .medium, .low, .info]
        let sorted = issues.sorted { priorityOrder.firstIndex(of: $0.severity)! < priorityOrder.firstIndex(of: $1.severity)! }

        for issue in sorted {
            let normalizedMessage = normalizeMessage(issue.message)
            let key = "\(issue.filePath):\(issue.line ?? 0):\(normalizedMessage)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(issue)
            }
        }
        return unique
    }

    private func normalizeMessage(_ message: String) -> String {
        var msg = message.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".'\""))

        let prefixesToRemove = [
            "the named parameter ",
            "unused import: ",
            "don't invoke ",
        ]
        for prefix in prefixesToRemove {
            if msg.hasPrefix(prefix) {
                msg = String(msg.dropFirst(prefix.count))
            }
        }

        return String(msg.prefix(80))
    }

    private func adjustSeverityForTestCode(_ issues: [Issue]) -> [Issue] {
        issues.map { issue in
            let isTestFile = issue.filePath.contains("/test/") ||
                issue.filePath.contains("/tests/") ||
                issue.filePath.contains("_test.") ||
                issue.filePath.contains("Test.") ||
                issue.filePath.contains("/Fixtures/")

            guard isTestFile && issue.severity == .critical else {
                return issue
            }

            return Issue(
                rule: issue.rule,
                message: issue.message,
                severity: .high,
                filePath: issue.filePath,
                line: issue.line,
                column: issue.column,
                scanner: issue.scanner,
                isFixed: issue.isFixed
            )
        }
    }

    private func runFixPhase(_ results: inout [FixResult]) async {
        for fixer in fixers {
            log(.info, "Running \(fixer.name) auto-fix...")
            do {
                let result = try await fixer.fix(projectPath: config.projectPath)
                results.append(result)
                log(.success, "\(fixer.name): fixed \(result.fixedIssueCount) issues in \(result.fixedFiles)/\(result.totalFiles) files")
            } catch {
                log(.error, "\(fixer.name) fix failed: \(error.localizedDescription)")
            }
        }
    }
}

public enum PipelineError: LocalizedError {
    case noScanReport
    case noBackup

    public var errorDescription: String? {
        switch self {
        case .noScanReport: "No scan report available. Run scan() first."
        case .noBackup: "No backup available to rollback."
        }
    }
}
