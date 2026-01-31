import SwiftUI
import OhMyBugCore

struct ScanReportView: View {
    let report: ScanReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                summaryCard
                if report.buildSucceeded != nil {
                    buildStatus
                }
                issuesByScanner
                issuesByRule
                affectedFiles
            }
            .padding(24)
        }
        .background(Theme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Scan Report")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text(String(format: "%.1fs", report.completedAt.timeIntervalSince(report.startedAt)))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(report.projectPath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
            Text("Review the issues below. Click 'Apply Fixes' to auto-fix, or 'Dismiss' to skip.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.warning)
                .padding(.top, 4)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 16) {
            summaryItem("Total", count: report.summary.total, color: Theme.textPrimary)
            summaryItem("Critical", count: report.summary.critical, color: Theme.error)
            summaryItem("High", count: report.summary.high, color: Theme.warning)
            summaryItem("Medium", count: report.summary.medium, color: .orange)
            summaryItem("Low", count: report.summary.low, color: Theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    private func summaryItem(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(count > 0 ? color : Theme.textSecondary.opacity(0.4))
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var buildStatus: some View {
        HStack(spacing: 8) {
            Text("Build:")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
            if report.buildSucceeded == true {
                Text("SUCCEEDED ✅")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.success)
            } else {
                Text("FAILED ❌")
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

    private var issuesByScanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By Scanner")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)

            ForEach(report.scanResults, id: \.scanner) { result in
                HStack {
                    Text(result.scanner)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text("\(result.scannedFiles) files")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(result.totalCount) issues")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(result.totalCount > 0 ? Theme.warning : Theme.success)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var issuesByRule: some View {
        let grouped = Dictionary(grouping: report.issues, by: \.rule)
            .sorted { $0.value.count > $1.value.count }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Issues by Rule (\(report.issues.count))")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)

            if grouped.isEmpty {
                Text("No issues found!")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.success)
            } else {
                ForEach(grouped.prefix(30), id: \.key) { rule, issues in
                    HStack {
                        Circle()
                            .fill(colorForSeverity(issues.first?.severity ?? .low))
                            .frame(width: 6, height: 6)
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
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private var affectedFiles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Affected Files (\(report.affectedFiles.count))")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)

            ForEach(report.affectedFiles.prefix(20), id: \.self) { file in
                let shortPath = file.hasPrefix(report.projectPath)
                    ? String(file.dropFirst(report.projectPath.count + 1))
                    : file
                let issueCount = report.issues.filter { $0.filePath == file }.count

                HStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                    Text(shortPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text("\(issueCount)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
            }

            if report.affectedFiles.count > 20 {
                Text("... and \(report.affectedFiles.count - 20) more files")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 12)
            }
        }
    }

    private func colorForSeverity(_ severity: Severity) -> Color {
        switch severity {
        case .critical: Theme.error
        case .high: Theme.warning
        case .medium: .orange
        case .low: Theme.textSecondary
        case .info: Theme.textSecondary.opacity(0.5)
        }
    }
}
