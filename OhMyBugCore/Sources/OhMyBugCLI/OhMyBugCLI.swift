import ArgumentParser
import OhMyBugCore
import Foundation

@main
struct OhMyBugCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ohmybug",
        abstract: "Automatically find and fix bugs, lint issues, and code quality problems.",
        version: "1.0.0",
        subcommands: [Check.self],
        defaultSubcommand: Check.self
    )
}

struct Check: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Scan and fix a project"
    )

    @Argument(help: "Path to the project directory")
    var projectPath: String = "."

    @Option(name: .long, help: "Output format: text, markdown, json, sarif, html")
    var format: String = "text"

    @Option(name: [.customShort("o"), .long], help: "Save report to file (e.g., report.html, report.sarif)")
    var output: String?

    @Flag(name: .long, help: "Show detailed output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Auto-fix after scan (creates backup first)")
    var fix: Bool = false

    @Option(name: .long, help: "GLM API key for AI auto-fix")
    var glmKey: String?

    func run() async throws {
        let resolvedPath = (projectPath as NSString).standardizingPath
        let absolutePath = resolvedPath.hasPrefix("/")
            ? resolvedPath
            : FileManager.default.currentDirectoryPath + "/" + resolvedPath

        let guidances = SetupGuide.analyze(projectPath: absolutePath)
        printGuidance(guidances)

        let unsupportedPlatforms = guidances.filter {
            if case .unsupportedPlatform = $0.status { return true }
            return false
        }
        if !unsupportedPlatforms.isEmpty && guidances.count == unsupportedPlatforms.count {
            print("\n⛔ No supported project types detected. Exiting.")
            return
        }

        let config = ProjectConfig(
            projectPath: absolutePath,
            autoApplyFixes: fix,
            glmAPIKey: glmKey
        )

        let engine = PipelineEngine(config: config)
        let cliDelegate = CLIDelegate(verbose: verbose)
        await engine.setDelegate(cliDelegate)

        await engine.registerAllScanners()

        if let glmKey, !glmKey.isEmpty {
            await engine.registerAIFixer(apiKey: glmKey)
        }

        let scanReport = try await engine.scan()
        printScanSummary(scanReport)

        guard fix else {
            try outputReport(scanReport)
            print("\nScan only. Use --fix to apply auto-fixes.")
            return
        }

        print("\nApplying fixes (backup created)...")
        let report = try await engine.fix()

        if output != nil {
            try outputReport(report)
        } else {
            print(ReportFormatter.format(report, as: reportFormat))
        }

        if report.buildSucceeded == false {
            print("\n⚠️  Build failed after fixes.")
            print("Rolling back...")
            let restored = try await engine.rollback()
            print("✅ Rolled back \(restored) files")
        }
    }

    private var reportFormat: ReportFormat {
        ReportFormat(rawValue: format) ?? .text
    }

    private func outputReport(_ report: ScanReport) throws {
        guard let outputPath = output else { return }

        let formatted = ReportFormatter.format(report, as: reportFormat)
        let url = URL(fileURLWithPath: outputPath)

        try formatted.write(to: url, atomically: true, encoding: .utf8)
        print("\n📄 Report saved to: \(outputPath)")
    }

    private func outputReport(_ report: PipelineReport) throws {
        guard let outputPath = output else { return }

        let formatted = ReportFormatter.format(report, as: reportFormat)
        let url = URL(fileURLWithPath: outputPath)

        try formatted.write(to: url, atomically: true, encoding: .utf8)
        print("\n📄 Report saved to: \(outputPath)")
    }

    private func printGuidance(_ guidances: [SetupGuidance]) {
        guard !guidances.isEmpty else { return }

        let unsupported = guidances.filter {
            if case .unsupportedPlatform = $0.status { return true }
            return false
        }

        let versionIssues = guidances.filter {
            if case .unsupportedVersion = $0.status { return true }
            return false
        }

        if !unsupported.isEmpty {
            print("\n🚫 Unsupported Platforms Detected:")
            print("─────────────────────────────────")
            for guidance in unsupported {
                print("\n\(guidance.severityIcon) \(guidance.message)")
                for action in guidance.actions {
                    print("   → \(action)")
                }
                if let url = guidance.docsUrl {
                    print("   📚 \(url)")
                }
            }
        }

        if !versionIssues.isEmpty {
            print("\n⚠️  Version Compatibility Warnings:")
            print("──────────────────────────────────")
            for guidance in versionIssues {
                print("\n\(guidance.severityIcon) \(guidance.message)")
                for action in guidance.actions {
                    print("   → \(action)")
                }
                if let url = guidance.docsUrl {
                    print("   📚 \(url)")
                }
            }
        }

        if !unsupported.isEmpty || !versionIssues.isEmpty {
            print("")
        }
    }

    private func printScanSummary(_ report: ScanReport) {
        print("\n=== Scan Report ===")
        print("Total: \(report.summary.total) issues")
        print("  Critical: \(report.summary.critical)")
        print("  High: \(report.summary.high)")
        print("  Medium: \(report.summary.medium)")
        print("  Low: \(report.summary.low)")
        print("Affected files: \(report.affectedFiles.count)")

        let setupIssues = report.issues.filter { $0.rule.hasPrefix("setup/") }
        if !setupIssues.isEmpty {
            print("\n⚠️  Setup Issues:")
            for issue in setupIssues {
                print("  • \(issue.message)")
            }
        }

        let criticalIssues = report.issues.filter { $0.severity == .critical }
        if !criticalIssues.isEmpty {
            print("\n🚨 Critical Issues:")
            for issue in criticalIssues.prefix(5) {
                let location = issue.line.map { ":\($0)" } ?? ""
                print("  • [\(issue.rule)] \(issue.filePath)\(location): \(issue.message)")
            }
            if criticalIssues.count > 5 {
                print("  ... and \(criticalIssues.count - 5) more")
            }
        }
    }

}

final class CLIDelegate: PipelineDelegate, @unchecked Sendable {
    let verbose: Bool

    init(verbose: Bool) {
        self.verbose = verbose
    }

    func pipelineDidChangePhase(_ phase: ScanPhase) {
        print("[\(phase.rawValue)]")
    }

    func pipelineDidLog(_ entry: LogEntry) {
        guard verbose || entry.level != .debug else { return }
        let prefix: String
        switch entry.level {
        case .debug: prefix = "  "
        case .info: prefix = "→"
        case .warning: prefix = "⚠️"
        case .error: prefix = "❌"
        case .success: prefix = "✅"
        }
        print("\(prefix) \(entry.message)")
    }

    func pipelineDidUpdateProgress(_ progress: Double) {
        if verbose {
            print("  Progress: \(Int(progress * 100))%")
        }
    }
}
