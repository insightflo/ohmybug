import Foundation

public actor BackupManager {
    private let backupRoot: String
    private let projectPath: String
    private var snapshotPaths: [String: String] = [:]
    private var hasSnapshot = false

    public init(projectPath: String) {
        self.projectPath = projectPath
        let sessionID = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        backupRoot = NSTemporaryDirectory() + "OhMyBug/\(sessionID)"
    }

    public func createSnapshot(files: [String]) throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: backupRoot, withIntermediateDirectories: true)

        for filePath in files {
            guard fm.fileExists(atPath: filePath) else { continue }

            let relativePath = filePath.hasPrefix(projectPath)
                ? String(filePath.dropFirst(projectPath.count + 1))
                : filePath

            let backupPath = "\(backupRoot)/\(relativePath)"
            let backupDir = (backupPath as NSString).deletingLastPathComponent
            try fm.createDirectory(atPath: backupDir, withIntermediateDirectories: true)
            try fm.copyItem(atPath: filePath, toPath: backupPath)
            snapshotPaths[filePath] = backupPath
        }
        hasSnapshot = true
    }

    public func rollback() throws -> Int {
        guard hasSnapshot else { return 0 }
        let fm = FileManager.default
        var restoredCount = 0

        for (originalPath, backupPath) in snapshotPaths {
            guard fm.fileExists(atPath: backupPath) else { continue }
            if fm.fileExists(atPath: originalPath) {
                try fm.removeItem(atPath: originalPath)
            }
            try fm.copyItem(atPath: backupPath, toPath: originalPath)
            restoredCount += 1
        }
        return restoredCount
    }

    public func cleanup() {
        try? FileManager.default.removeItem(atPath: backupRoot)
        snapshotPaths = [:]
        hasSnapshot = false
    }

    public var snapshotExists: Bool {
        hasSnapshot
    }

    public var backedUpFileCount: Int {
        snapshotPaths.count
    }

    public var backupLocation: String {
        backupRoot
    }
}
