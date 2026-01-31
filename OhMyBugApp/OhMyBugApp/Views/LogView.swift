import SwiftUI
import OhMyBugCore

struct LogView: View {
    let entries: [LogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Execution Log")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(entries.count) entries")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding()
            .background(Theme.surface)

            Divider().overlay(Theme.border)

            if entries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.textSecondary.opacity(0.4))
                    Text("No logs yet")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Load a project and run Auto Mode to see output")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(entries) { entry in
                                logRow(entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: entries.count) {
                        if let last = entries.last {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(Theme.background)
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(formatTime(entry.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.textSecondary.opacity(0.6))
                .frame(width: 70, alignment: .leading)

            Circle()
                .fill(colorForLevel(entry.level))
                .frame(width: 6, height: 6)
                .offset(y: 4)

            Text(entry.message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(colorForLevel(entry.level).opacity(0.9))
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func colorForLevel(_ level: LogLevel) -> Color {
        switch level {
        case .debug: Theme.textSecondary
        case .info: Theme.textPrimary
        case .warning: Theme.warning
        case .error: Theme.error
        case .success: Theme.success
        }
    }
}
