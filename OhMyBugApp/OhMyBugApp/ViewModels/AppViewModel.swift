import SwiftUI
import OhMyBugCore

enum AppState {
    case idle
    case scanning
    case scanned
    case fixing
    case fixed
}

@Observable
@MainActor
final class AppViewModel {
    var projectPath: String?
    var projectType: ProjectType = .auto
    var currentPhase: ScanPhase = .idle
    var logEntries: [LogEntry] = []
    var scanReport: ScanReport?
    var fixReport: PipelineReport?
    var appState: AppState = .idle
    var settings = AppSettings()

    private var engine: PipelineEngine?
    private var bridge: DelegateBridge?

    var hasProject: Bool { projectPath != nil }
    var isRunning: Bool { appState == .scanning || appState == .fixing }
    var canFix: Bool { appState == .scanned && scanReport != nil }
    var canRollback: Bool { appState == .fixed }

    var projectName: String {
        guard let path = projectPath else { return "" }
        return (path as NSString).lastPathComponent
    }

    func loadProject(url: URL) {
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else { return }
        projectPath = path
        projectType = ProjectDetector.detect(at: path)
        logEntries = []
        scanReport = nil
        fixReport = nil
        appState = .idle
        currentPhase = .idle
        engine = nil
        appendLog(.info, "Loaded project: \(path)")
        appendLog(.info, "Detected type: \(projectType.rawValue)")
    }

    func runScan() {
        guard let projectPath, !isRunning else { return }
        appState = .scanning
        scanReport = nil
        fixReport = nil
        logEntries = []

        Task {
            let config = ProjectConfig(
                projectPath: projectPath,
                projectType: projectType,
                autoApplyFixes: settings.autoApplyFixes,
                runBuildCheck: settings.runBuildCheck,
                glmAPIKey: settings.glmAPIKey.isEmpty ? nil : settings.glmAPIKey
            )

            let eng = PipelineEngine(config: config)
            let br = DelegateBridge(viewModel: self)
            await eng.setDelegate(br)
            await eng.registerAllScanners()

            if !settings.glmAPIKey.isEmpty {
                await eng.registerAIFixer(apiKey: settings.glmAPIKey)
                appendLog(.info, "GLM AI auto-fix enabled (\(LLMConfig.glmModel))")
            }

            self.engine = eng
            self.bridge = br

            do {
                let report = try await eng.scan()
                self.scanReport = report
                self.appState = .scanned
                appendLog(.success, "Scan complete: \(report.issues.count) issues found")
                appendLog(.info, "Review the report, then click 'Apply Fixes' to proceed or 'Dismiss' to skip.")
            } catch {
                appendLog(.error, "Scan failed: \(error.localizedDescription)")
                self.appState = .idle
            }
        }
    }

    func applyFixes() {
        guard let engine, appState == .scanned else { return }
        appState = .fixing

        Task {
            do {
                let report = try await engine.fix()
                self.fixReport = report
                self.appState = .fixed
                appendLog(.success, "Fixes applied! \(report.beforeIssues.total) → \(report.afterIssues.total) issues")
                if report.buildSucceeded == false {
                    appendLog(.warning, "Build failed after fixes. Consider rolling back.")
                }
            } catch {
                appendLog(.error, "Fix failed: \(error.localizedDescription)")
                self.appState = .scanned
            }
        }
    }

    func rollback() {
        guard let engine, appState == .fixed else { return }

        Task {
            do {
                let count = try await engine.rollback()
                appendLog(.success, "Rolled back \(count) files to pre-fix state")
                self.fixReport = nil
                self.appState = .scanned
            } catch {
                appendLog(.error, "Rollback failed: \(error.localizedDescription)")
            }
        }
    }

    func dismiss() {
        Task {
            await engine?.cleanupBackup()
        }
        scanReport = nil
        fixReport = nil
        appState = .idle
        currentPhase = .idle
    }

    func appendLog(_ level: LogLevel, _ message: String, source: String? = nil) {
        logEntries.append(LogEntry(level: level, message: message, source: source))
    }
}

final class DelegateBridge: PipelineDelegate, @unchecked Sendable {
    private let viewModel: AppViewModel

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    func pipelineDidChangePhase(_ phase: ScanPhase) {
        Task { @MainActor in
            viewModel.currentPhase = phase
        }
    }

    func pipelineDidLog(_ entry: LogEntry) {
        Task { @MainActor in
            viewModel.logEntries.append(entry)
        }
    }

    func pipelineDidUpdateProgress(_ progress: Double) {}
}
