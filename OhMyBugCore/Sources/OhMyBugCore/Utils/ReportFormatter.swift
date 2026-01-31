import Foundation

public enum ReportFormat: String, CaseIterable, Sendable {
    case text
    case markdown
    case json
    case sarif
    case html
}

public enum ReportFormatter {

    public static func format(_ report: ScanReport, as format: ReportFormat) -> String {
        switch format {
        case .text:
            return formatScanText(report)
        case .markdown:
            return formatScanMarkdown(report)
        case .json:
            return formatScanJSON(report)
        case .sarif:
            return formatScanSARIF(report)
        case .html:
            return formatScanHTML(report)
        }
    }

    public static func format(_ report: PipelineReport, as format: ReportFormat) -> String {
        switch format {
        case .text:
            return formatPipelineText(report)
        case .markdown:
            return formatPipelineMarkdown(report)
        case .json:
            return formatPipelineJSON(report)
        case .sarif:
            return formatPipelineSARIF(report)
        case .html:
            return formatPipelineHTML(report)
        }
    }

    public static func suggestedExtension(for format: ReportFormat) -> String {
        switch format {
        case .text: return "txt"
        case .markdown: return "md"
        case .json: return "json"
        case .sarif: return "sarif"
        case .html: return "html"
        }
    }
}

extension ReportFormatter {

    private static func formatScanText(_ report: ScanReport) -> String {
        var output = "=== OhMyBug Scan Report ===\n"
        output += "Project: \(report.projectPath)\n"
        output += "Date: \(ISO8601DateFormatter().string(from: report.completedAt))\n\n"

        output += "Total: \(report.summary.total) issues\n"
        output += "  Critical: \(report.summary.critical)\n"
        output += "  High: \(report.summary.high)\n"
        output += "  Medium: \(report.summary.medium)\n"
        output += "  Low: \(report.summary.low)\n"
        output += "Affected files: \(report.affectedFiles.count)\n"

        if !report.issues.isEmpty {
            output += "\n--- Issues ---\n"
            for issue in report.issues {
                let location = issue.line.map { ":\($0)" } ?? ""
                output += "[\(issue.severity.rawValue.uppercased())] \(issue.filePath)\(location)\n"
                output += "  Rule: \(issue.rule)\n"
                output += "  \(issue.message)\n\n"
            }
        }

        return output
    }

    private static func formatScanMarkdown(_ report: ScanReport) -> String {
        var md = "# OhMyBug Scan Report\n\n"
        md += "**Project**: `\(report.projectPath)`\n"
        md += "**Date**: \(ISO8601DateFormatter().string(from: report.completedAt))\n\n"

        md += "## Summary\n\n"
        md += "| Severity | Count |\n"
        md += "|----------|-------|\n"
        md += "| Critical | \(report.summary.critical) |\n"
        md += "| High | \(report.summary.high) |\n"
        md += "| Medium | \(report.summary.medium) |\n"
        md += "| Low | \(report.summary.low) |\n"
        md += "| **Total** | **\(report.summary.total)** |\n\n"

        if !report.issues.isEmpty {
            md += "## Issues\n\n"
            let groupedByFile = Dictionary(grouping: report.issues) { $0.filePath }

            for (file, issues) in groupedByFile.sorted(by: { $0.key < $1.key }) {
                let relativePath = file.replacingOccurrences(of: report.projectPath + "/", with: "")
                md += "### `\(relativePath)`\n\n"

                for issue in issues {
                    let line = issue.line.map { "L\($0)" } ?? ""
                    let severity = severityEmoji(issue.severity)
                    md += "- \(severity) **\(issue.rule)** \(line): \(issue.message)\n"
                }
                md += "\n"
            }
        }

        return md
    }

    private static func formatScanJSON(_ report: ScanReport) -> String {
        let exportable = ScanReportExport(
            projectPath: report.projectPath,
            startedAt: report.startedAt,
            completedAt: report.completedAt,
            summary: report.summary,
            issues: report.issues,
            scanResults: report.scanResults,
            affectedFiles: report.affectedFiles
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(exportable) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func severityEmoji(_ severity: Severity) -> String {
        switch severity {
        case .critical: return "🔴"
        case .high: return "🟠"
        case .medium: return "🟡"
        case .low: return "🔵"
        case .info: return "⚪"
        }
    }
}

extension ReportFormatter {

    private static func formatScanSARIF(_ report: ScanReport) -> String {
        let sarif = SARIFReport(
            version: "2.1.0",
            schema: "https://json.schemastore.org/sarif-2.1.0.json",
            runs: [
                SARIFRun(
                    tool: SARIFTool(
                        driver: SARIFDriver(
                            name: "OhMyBug",
                            semanticVersion: "1.0.0",
                            informationUri: "https://github.com/insightflo/ohmybug"
                        )
                    ),
                    results: report.issues.map { issue in
                        SARIFResult(
                            ruleId: issue.rule,
                            level: sarifLevel(issue.severity),
                            message: SARIFMessage(text: issue.message),
                            locations: [
                                SARIFLocation(
                                    physicalLocation: SARIFPhysicalLocation(
                                        artifactLocation: SARIFArtifactLocation(
                                            uri: issue.filePath.replacingOccurrences(of: report.projectPath + "/", with: "")
                                        ),
                                        region: SARIFRegion(
                                            startLine: issue.line ?? 1,
                                            startColumn: issue.column ?? 1
                                        )
                                    )
                                )
                            ]
                        )
                    }
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(sarif) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func formatPipelineSARIF(_ report: PipelineReport) -> String {
        var allIssues: [Issue] = []
        for scanResult in report.scanResults {
            allIssues.append(contentsOf: scanResult.issues)
        }

        let sarif = SARIFReport(
            version: "2.1.0",
            schema: "https://json.schemastore.org/sarif-2.1.0.json",
            runs: [
                SARIFRun(
                    tool: SARIFTool(
                        driver: SARIFDriver(
                            name: "OhMyBug",
                            semanticVersion: "1.0.0",
                            informationUri: "https://github.com/insightflo/ohmybug"
                        )
                    ),
                    results: allIssues.map { issue in
                        SARIFResult(
                            ruleId: issue.rule,
                            level: sarifLevel(issue.severity),
                            message: SARIFMessage(text: issue.message),
                            locations: [
                                SARIFLocation(
                                    physicalLocation: SARIFPhysicalLocation(
                                        artifactLocation: SARIFArtifactLocation(
                                            uri: issue.filePath.replacingOccurrences(of: report.projectPath + "/", with: "")
                                        ),
                                        region: SARIFRegion(
                                            startLine: issue.line ?? 1,
                                            startColumn: issue.column ?? 1
                                        )
                                    )
                                )
                            ]
                        )
                    }
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(sarif) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func sarifLevel(_ severity: Severity) -> String {
        switch severity {
        case .critical, .high: return "error"
        case .medium: return "warning"
        case .low, .info: return "note"
        }
    }
}

extension ReportFormatter {

    private static func formatScanHTML(_ report: ScanReport) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var html = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OhMyBug Scan Report</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 {
            color: #1a1a2e;
            margin-bottom: 10px;
            font-size: 2rem;
        }
        .meta { color: #666; margin-bottom: 30px; }
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
        }
        .summary-card {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            text-align: center;
        }
        .summary-card.critical { border-left: 4px solid #dc3545; }
        .summary-card.high { border-left: 4px solid #fd7e14; }
        .summary-card.medium { border-left: 4px solid #ffc107; }
        .summary-card.low { border-left: 4px solid #17a2b8; }
        .summary-card.total { border-left: 4px solid #6c757d; }
        .summary-card h3 { font-size: 2rem; margin-bottom: 5px; }
        .summary-card p { color: #666; font-size: 0.9rem; }
        .issues-section { background: white; border-radius: 10px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .issues-section h2 { margin-bottom: 20px; color: #1a1a2e; }
        .file-group { margin-bottom: 25px; }
        .file-name {
            font-family: 'Monaco', 'Menlo', monospace;
            background: #e9ecef;
            padding: 8px 12px;
            border-radius: 5px;
            margin-bottom: 10px;
            font-size: 0.9rem;
        }
        .issue {
            padding: 12px;
            margin-bottom: 8px;
            border-radius: 5px;
            border-left: 4px solid;
        }
        .issue.critical { background: #f8d7da; border-color: #dc3545; }
        .issue.high { background: #ffe5d0; border-color: #fd7e14; }
        .issue.medium { background: #fff3cd; border-color: #ffc107; }
        .issue.low { background: #d1ecf1; border-color: #17a2b8; }
        .issue-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 5px; }
        .issue-rule { font-weight: bold; font-family: monospace; }
        .issue-location { color: #666; font-size: 0.85rem; }
        .issue-message { color: #333; }
        .badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 0.75rem;
            font-weight: bold;
            text-transform: uppercase;
        }
        .badge.critical { background: #dc3545; color: white; }
        .badge.high { background: #fd7e14; color: white; }
        .badge.medium { background: #ffc107; color: #333; }
        .badge.low { background: #17a2b8; color: white; }
        .no-issues { text-align: center; padding: 40px; color: #28a745; }
        .no-issues h3 { font-size: 1.5rem; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐛 OhMyBug Scan Report</h1>
        <p class="meta">
            <strong>Project:</strong> \(report.projectPath)<br>
            <strong>Date:</strong> \(dateFormatter.string(from: report.completedAt))
        </p>

        <div class="summary-grid">
            <div class="summary-card critical">
                <h3>\(report.summary.critical)</h3>
                <p>Critical</p>
            </div>
            <div class="summary-card high">
                <h3>\(report.summary.high)</h3>
                <p>High</p>
            </div>
            <div class="summary-card medium">
                <h3>\(report.summary.medium)</h3>
                <p>Medium</p>
            </div>
            <div class="summary-card low">
                <h3>\(report.summary.low)</h3>
                <p>Low</p>
            </div>
            <div class="summary-card total">
                <h3>\(report.summary.total)</h3>
                <p>Total Issues</p>
            </div>
        </div>

        <div class="issues-section">
            <h2>Issues</h2>
"""

        if report.issues.isEmpty {
            html += """
            <div class="no-issues">
                <h3>✅ No issues found!</h3>
                <p>Your code looks great.</p>
            </div>
"""
        } else {
            let groupedByFile = Dictionary(grouping: report.issues) { $0.filePath }

            for (file, issues) in groupedByFile.sorted(by: { $0.key < $1.key }) {
                let relativePath = file.replacingOccurrences(of: report.projectPath + "/", with: "")
                html += """
            <div class="file-group">
                <div class="file-name">📄 \(relativePath)</div>
"""
                for issue in issues.sorted(by: { ($0.line ?? 0) < ($1.line ?? 0) }) {
                    let severityClass = issue.severity.rawValue
                    let location = issue.line.map { "Line \($0)" } ?? ""
                    html += """
                <div class="issue \(severityClass)">
                    <div class="issue-header">
                        <span class="issue-rule">\(issue.rule)</span>
                        <span class="badge \(severityClass)">\(issue.severity.rawValue)</span>
                    </div>
                    <div class="issue-location">\(location)</div>
                    <div class="issue-message">\(escapeHTML(issue.message))</div>
                </div>
"""
                }
                html += "            </div>\n"
            }
        }

        html += """
        </div>
    </div>
</body>
</html>
"""
        return html
    }

    private static func formatPipelineHTML(_ report: PipelineReport) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var allIssues: [Issue] = []
        for scanResult in report.scanResults {
            allIssues.append(contentsOf: scanResult.issues)
        }

        var html = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OhMyBug Pipeline Report</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 { color: #1a1a2e; margin-bottom: 10px; font-size: 2rem; }
        h2 { color: #1a1a2e; margin: 30px 0 15px; }
        .meta { color: #666; margin-bottom: 30px; }
        .comparison {
            display: grid;
            grid-template-columns: 1fr auto 1fr;
            gap: 20px;
            align-items: center;
            margin-bottom: 30px;
        }
        .comparison-card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            text-align: center;
        }
        .comparison-card h3 { font-size: 2.5rem; margin-bottom: 5px; }
        .comparison-card.before { border-top: 4px solid #dc3545; }
        .comparison-card.after { border-top: 4px solid #28a745; }
        .arrow { font-size: 2rem; color: #28a745; }
        .reduction {
            background: #28a745;
            color: white;
            padding: 10px 20px;
            border-radius: 20px;
            font-weight: bold;
            display: inline-block;
            margin-bottom: 30px;
        }
        .fix-results {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 30px;
        }
        .fix-item {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid #eee;
        }
        .fix-item:last-child { border-bottom: none; }
        .issues-section {
            background: white;
            border-radius: 10px;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .issue {
            padding: 12px;
            margin-bottom: 8px;
            border-radius: 5px;
            border-left: 4px solid;
        }
        .issue.critical { background: #f8d7da; border-color: #dc3545; }
        .issue.high { background: #ffe5d0; border-color: #fd7e14; }
        .issue.medium { background: #fff3cd; border-color: #ffc107; }
        .issue.low { background: #d1ecf1; border-color: #17a2b8; }
        .badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 0.75rem;
            font-weight: bold;
        }
        .badge.critical { background: #dc3545; color: white; }
        .badge.high { background: #fd7e14; color: white; }
        .badge.medium { background: #ffc107; color: #333; }
        .badge.low { background: #17a2b8; color: white; }
        .build-status {
            padding: 15px 25px;
            border-radius: 10px;
            font-weight: bold;
            margin-bottom: 30px;
        }
        .build-status.success { background: #d4edda; color: #155724; }
        .build-status.failed { background: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐛 OhMyBug Pipeline Report</h1>
        <p class="meta">
            <strong>Project:</strong> \(report.projectPath)<br>
            <strong>Duration:</strong> \(String(format: "%.1f", report.duration))s
        </p>

        <div class="comparison">
            <div class="comparison-card before">
                <h3>\(report.beforeIssues.total)</h3>
                <p>Issues Before</p>
            </div>
            <div class="arrow">→</div>
            <div class="comparison-card after">
                <h3>\(report.afterIssues.total)</h3>
                <p>Issues After</p>
            </div>
        </div>

        <div style="text-align: center;">
            <span class="reduction">↓ \(String(format: "%.0f", report.reductionPercentage))% Reduction</span>
        </div>
"""

        if let buildOK = report.buildSucceeded {
            let statusClass = buildOK ? "success" : "failed"
            let statusText = buildOK ? "✅ Build Succeeded" : "❌ Build Failed"
            html += """
        <div class="build-status \(statusClass)">\(statusText)</div>
"""
        }

        if !report.fixResults.isEmpty {
            html += """
        <h2>Fix Results</h2>
        <div class="fix-results">
"""
            for fix in report.fixResults {
                html += """
            <div class="fix-item">
                <span><strong>\(fix.tool)</strong></span>
                <span>\(fix.fixedIssueCount) issues fixed in \(fix.fixedFiles) files</span>
            </div>
"""
            }
            html += "        </div>\n"
        }

        if !allIssues.isEmpty {
            html += """
        <h2>Remaining Issues (\(allIssues.count))</h2>
        <div class="issues-section">
"""
            for issue in allIssues.prefix(50) {
                let severityClass = issue.severity.rawValue
                let location = issue.line.map { "Line \($0)" } ?? ""
                html += """
            <div class="issue \(severityClass)">
                <span class="badge \(severityClass)">\(issue.severity.rawValue)</span>
                <strong>\(issue.rule)</strong> \(location)<br>
                \(escapeHTML(issue.message))
            </div>
"""
            }
            if allIssues.count > 50 {
                html += "            <p style=\"text-align:center;color:#666;\">...and \(allIssues.count - 50) more issues</p>\n"
            }
            html += "        </div>\n"
        }

        html += """
    </div>
</body>
</html>
"""
        return html
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

extension ReportFormatter {

    private static func formatPipelineText(_ report: PipelineReport) -> String {
        var output = "\n=== OhMyBug Pipeline Report ===\n"
        output += "Project: \(report.projectPath)\n"
        output += "Duration: \(String(format: "%.1f", report.duration))s\n\n"

        output += "Before: \(report.beforeIssues.total) issues"
        output += " (Critical: \(report.beforeIssues.critical), High: \(report.beforeIssues.high), Medium: \(report.beforeIssues.medium))\n"
        output += "After:  \(report.afterIssues.total) issues"
        output += " (Critical: \(report.afterIssues.critical), High: \(report.afterIssues.high), Medium: \(report.afterIssues.medium))\n"
        output += "Reduction: \(String(format: "%.0f", report.reductionPercentage))%\n"

        if let buildOK = report.buildSucceeded {
            output += "\nBuild: \(buildOK ? "SUCCEEDED" : "FAILED")\n"
        }

        return output
    }

    private static func formatPipelineMarkdown(_ report: PipelineReport) -> String {
        var md = "# OhMyBug Pipeline Report\n\n"
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

    private static func formatPipelineJSON(_ report: PipelineReport) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(report) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

private struct ScanReportExport: Codable {
    let projectPath: String
    let startedAt: Date
    let completedAt: Date
    let summary: IssueSummary
    let issues: [Issue]
    let scanResults: [ScanResult]
    let affectedFiles: [String]
}

private struct SARIFReport: Codable {
    let version: String
    let schema: String
    let runs: [SARIFRun]

    enum CodingKeys: String, CodingKey {
        case version
        case schema = "$schema"
        case runs
    }
}

private struct SARIFRun: Codable {
    let tool: SARIFTool
    let results: [SARIFResult]
}

private struct SARIFTool: Codable {
    let driver: SARIFDriver
}

private struct SARIFDriver: Codable {
    let name: String
    let semanticVersion: String
    let informationUri: String
}

private struct SARIFResult: Codable {
    let ruleId: String
    let level: String
    let message: SARIFMessage
    let locations: [SARIFLocation]
}

private struct SARIFMessage: Codable {
    let text: String
}

private struct SARIFLocation: Codable {
    let physicalLocation: SARIFPhysicalLocation
}

private struct SARIFPhysicalLocation: Codable {
    let artifactLocation: SARIFArtifactLocation
    let region: SARIFRegion
}

private struct SARIFArtifactLocation: Codable {
    let uri: String
}

private struct SARIFRegion: Codable {
    let startLine: Int
    let startColumn: Int
}
