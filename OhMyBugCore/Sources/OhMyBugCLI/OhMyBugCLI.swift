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

    @Option(name: .long, help: "Output format: text, markdown, json")
    var format: String = "text"

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
            print("\nScan only. Use --fix to apply auto-fixes.")
            return
        }

        print("\nApplying fixes (backup created)...")
        let report = try await engine.fix()
        print(formatReport(report))

        if report.buildSucceeded == false {
            print("\n⚠️  Build failed after fixes.")
            print("Rolling back...")
            let restored = try await engine.rollback()
            print("✅ Rolled back \(restored) files")
        }
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

    private func formatReport(_ report: PipelineReport) -> String {
        switch format {
        case "markdown":
            return formatMarkdown(report)
        case "json":
            return formatJSON(report)
        default:
            return formatText(report)
        }
    }

    private func formatText(_ report: PipelineReport) -> String {
        var output = "\n=== OhMyBug Scan Complete ===\n"
        output += "Project: \(report.projectPath)\n"
        output += "Duration: \(String(format: "%.1f", report.duration))s\n\n"

        output += "Before: \(report.beforeIssues.total) issues"
        output += " (Critical: \(report.beforeIssues.critical), High: \(report.beforeIssues.high), Medium: \(report.beforeIssues.medium))\n"
        output += "After:  \(report.afterIssues.total) issues"
        output += " (Critical: \(report.afterIssues.critical), High: \(report.afterIssues.high), Medium: \(report.afterIssues.medium))\n"
        output += "Reduction: \(String(format: "%.0f", report.reductionPercentage))%\n"

        if let buildOK = report.buildSucceeded {
            output += "\nBuild: \(buildOK ? "SUCCEEDED ✅" : "FAILED ❌")\n"
        }

        return output
    }

    private func formatMarkdown(_ report: PipelineReport) -> String {
        var md = "# OhMyBug Scan Report\n\n"
        md += "| Metric | Before | After | Change |\n"
        md += "|--------|--------|-------|--------|\n"
        md += "| Total | \(report.beforeIssues.total) | \(report.afterIssues.total) | -\(String(format: "%.0f", report.reductionPercentage))% |\n"
        md += "| Critical | \(report.beforeIssues.critical) | \(report.afterIssues.critical) | |\n"
        md += "| High | \(report.beforeIssues.high) | \(report.afterIssues.high) | |\n"
        md += "| Medium | \(report.beforeIssues.medium) | \(report.afterIssues.medium) | |\n"

        if let buildOK = report.buildSucceeded {
            md += "\n**Build**: \(buildOK ? "SUCCEEDED ✅" : "FAILED ❌")\n"
        }

        if !report.fixResults.isEmpty {
            md += "\n## Auto-Fix Summary\n\n"
            for fix in report.fixResults {
                md += "- **\(fix.tool)**: \(fix.fixedFiles)/\(fix.totalFiles) files, \(fix.fixedIssueCount) issues fixed\n"
            }
        }

        return md
    }

    private func formatJSON(_ report: PipelineReport) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(report) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
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
