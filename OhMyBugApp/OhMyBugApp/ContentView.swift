import SwiftUI
import OhMyBugCore

struct ContentView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 320)
        } detail: {
            detail
        }
        .background(Theme.background)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("OhMyBug")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.accent)

                ProjectDropZone(
                    projectPath: viewModel.projectPath,
                    projectName: viewModel.projectName,
                    projectType: viewModel.projectType
                ) { url in
                    viewModel.loadProject(url: url)
                }
            }
            .padding()

            Divider().overlay(Theme.border)

            actionButtons
                .padding()

            if viewModel.currentPhase != .idle {
                PhaseIndicator(currentPhase: viewModel.currentPhase)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }

            Divider().overlay(Theme.border)

            SettingsPanel(settings: viewModel.settings)
                .padding()

            Spacer()
        }
        .background(Theme.surface)
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            switch viewModel.appState {
            case .idle:
                scanButton
            case .scanning:
                runningButton("Scanning...")
            case .scanned:
                fixButton
                dismissButton
            case .fixing:
                runningButton("Fixing...")
            case .fixed:
                rollbackButton
                dismissButton
            }
        }
    }

    private var scanButton: some View {
        Button(action: { viewModel.runScan() }) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Scan Project")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .foregroundStyle(.black)
        .disabled(!viewModel.hasProject)
    }

    private var fixButton: some View {
        Button(action: { viewModel.applyFixes() }) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                Text("Apply Fixes")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.warning)
        .foregroundStyle(.black)
    }

    private var rollbackButton: some View {
        Button(action: { viewModel.rollback() }) {
            HStack {
                Image(systemName: "arrow.uturn.backward")
                Text("Rollback")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.error)
        .foregroundStyle(.white)
    }

    private var dismissButton: some View {
        Button(action: { viewModel.dismiss() }) {
            Text("Dismiss")
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(Theme.textSecondary)
    }

    private func runningButton(_ label: String) -> some View {
        HStack {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)
            Text(label)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surfaceLight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var detail: some View {
        switch viewModel.appState {
        case .scanned:
            if let report = viewModel.scanReport {
                ScanReportView(report: report)
            } else {
                LogView(entries: viewModel.logEntries)
            }
        case .fixed:
            if let report = viewModel.fixReport {
                ResultsDashboard(report: report)
            } else {
                LogView(entries: viewModel.logEntries)
            }
        default:
            LogView(entries: viewModel.logEntries)
        }
    }
}
