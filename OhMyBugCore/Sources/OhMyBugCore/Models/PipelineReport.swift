import Foundation

public struct PipelineReport: Codable, Sendable {
    public let projectPath: String
    public let startedAt: Date
    public let completedAt: Date
    public let beforeIssues: IssueSummary
    public let afterIssues: IssueSummary
    public let scanResults: [ScanResult]
    public let fixResults: [FixResult]
    public let buildSucceeded: Bool?

    public init(
        projectPath: String,
        startedAt: Date,
        completedAt: Date,
        beforeIssues: IssueSummary,
        afterIssues: IssueSummary,
        scanResults: [ScanResult],
        fixResults: [FixResult],
        buildSucceeded: Bool?
    ) {
        self.projectPath = projectPath
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.beforeIssues = beforeIssues
        self.afterIssues = afterIssues
        self.scanResults = scanResults
        self.fixResults = fixResults
        self.buildSucceeded = buildSucceeded
    }

    public var reductionPercentage: Double {
        guard beforeIssues.total > 0 else { return 0 }
        return Double(beforeIssues.total - afterIssues.total) / Double(beforeIssues.total) * 100
    }

    public var duration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }
}

public struct IssueSummary: Codable, Sendable {
    public let total: Int
    public let critical: Int
    public let high: Int
    public let medium: Int
    public let low: Int

    public init(total: Int, critical: Int, high: Int, medium: Int, low: Int) {
        self.total = total
        self.critical = critical
        self.high = high
        self.medium = medium
        self.low = low
    }

    public static func from(issues: [Issue]) -> IssueSummary {
        IssueSummary(
            total: issues.count,
            critical: issues.filter { $0.severity == .critical }.count,
            high: issues.filter { $0.severity == .high }.count,
            medium: issues.filter { $0.severity == .medium }.count,
            low: issues.filter { $0.severity == .low }.count
        )
    }
}
