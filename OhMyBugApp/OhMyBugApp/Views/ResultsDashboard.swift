import SwiftUI
import OhMyBugCore

struct ResultsDashboard: View {
    let report: PipelineReport
    var onExport: ((ReportFormat) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                comparisonTable
                if report.buildSucceeded != nil {
                    buildStatus
                }
                if !report.fixResults.isEmpty {
                    fixSummary
                }
                remainingIssues
            }
            .padding(24)
        }
        .background(Theme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("OhMyBug Scan Complete")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                Spacer()
                exportMenu
                Text(String(format: "%.1fs", report.duration))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(report.projectPath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var exportMenu: some View {
        Menu {
            Button("Export as HTML") { onExport?(.html) }
            Button("Export as Markdown") { onExport?(.markdown) }
            Button("Export as JSON") { onExport?(.json) }
            Button("Export as SARIF") { onExport?(.sarif) }
            Divider()
            Button("Export as Text") { onExport?(.text) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.down")
                Text("Export")
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            tableHeader
            Divider().overlay(Theme.border)
            tableRow("Total Issues", before: report.beforeIssues.total, after: report.afterIssues.total)
            tableRow("Critical", before: report.beforeIssues.critical, after: report.afterIssues.critical)
            tableRow("High", before: report.beforeIssues.high, after: report.afterIssues.high)
            tableRow("Medium", before: report.beforeIssues.medium, after: report.afterIssues.medium)
            tableRow("Low", before: report.beforeIssues.low, after: report.afterIssues.low)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    private var tableHeader: some View {
        HStack {
            Text("Metric")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Before")
                .frame(width: 80, alignment: .trailing)
            Text("After")
                .frame(width: 80, alignment: .trailing)
            Text("Change")
                .frame(width: 80, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surfaceLight)
    }

    private func tableRow(_ label: String, before: Int, after: Int) -> some View {
        let change = before > 0
            ? String(format: "-%0.0f%%", Double(before - after) / Double(before) * 100)
            : "-"

        return VStack(spacing: 0) {
            HStack {
                Text(label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(before)")
                    .frame(width: 80, alignment: .trailing)
                Text("\(after)")
                    .frame(width: 80, alignment: .trailing)
                Text(change)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.system(size: 12, weight: label == "Total Issues" ? .bold : .regular, design: .monospaced))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().overlay(Theme.border.opacity(0.5))
        }
    }

    private var buildStatus: some View {
        HStack(spacing: 8) {
            Text("Build Verification:")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
            if report.buildSucceeded == true {
                Text("BUILD SUCCEEDED ✅")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.success)
            } else {
                Text("BUILD FAILED ❌")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.error)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    private var fixSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Auto-Fix Summary")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)

            ForEach(report.fixResults, id: \.tool) { fix in
                HStack {
                    Text(fix.tool)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text("\(fix.fixedFiles)/\(fix.totalFiles) files")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(fix.fixedIssueCount) fixed")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.success)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var remainingIssues: some View {
        let allIssues = report.scanResults.flatMap(\.issues)
        let grouped = Dictionary(grouping: allIssues, by: \.rule)
            .sorted { $0.value.count > $1.value.count }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Remaining Issues (\(allIssues.count))")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)

            if grouped.isEmpty {
                Text("No remaining issues!")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.success)
            } else {
                ForEach(grouped.prefix(20), id: \.key) { rule, issues in
                    HStack {
                        Text(rule)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(issues.count)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Theme.warning.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
