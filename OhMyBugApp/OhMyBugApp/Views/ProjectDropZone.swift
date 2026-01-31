import SwiftUI
import AppKit
import OhMyBugCore

struct ProjectDropZone: View {
    let projectPath: String?
    let projectName: String
    let projectType: ProjectType
    let onDrop: (URL) -> Void

    @State private var isTargeted = false
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 8) {
            if let projectPath {
                Image(systemName: "folder.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.accent)
                Text(projectName)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                Text(projectPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(projectType.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(isHovering ? Theme.accent : Theme.textSecondary)
                Text("Drop Project or Click to Open")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isHovering ? Theme.accent : Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isTargeted || isHovering ? Theme.accent.opacity(0.1) : Theme.surfaceLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isTargeted || isHovering ? Theme.accent : Theme.border,
                    style: StrokeStyle(lineWidth: 1.5, dash: projectPath == nil ? [6] : [])
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            openFolderPicker()
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                      isDir.boolValue else { return }
                DispatchQueue.main.async {
                    onDrop(url)
                }
            }
            return true
        }
    }

    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.title = "Select Project Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            onDrop(url)
        }
    }
}
