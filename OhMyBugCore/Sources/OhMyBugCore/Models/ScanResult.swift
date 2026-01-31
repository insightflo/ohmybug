import Foundation

public struct ScanResult: Codable, Sendable {
    public let scanner: String
    public let issues: [Issue]
    public let fixedCount: Int
    public let scannedFiles: Int
    public let duration: TimeInterval

    public init(
        scanner: String,
        issues: [Issue],
        fixedCount: Int,
        scannedFiles: Int,
        duration: TimeInterval
    ) {
        self.scanner = scanner
        self.issues = issues
        self.fixedCount = fixedCount
        self.scannedFiles = scannedFiles
        self.duration = duration
    }

    public var totalCount: Int {
        issues.count
    }

    public var criticalCount: Int {
        issues.filter { $0.severity == .critical }.count
    }

    public var highCount: Int {
        issues.filter { $0.severity == .high }.count
    }

    public var mediumCount: Int {
        issues.filter { $0.severity == .medium }.count
    }
}
