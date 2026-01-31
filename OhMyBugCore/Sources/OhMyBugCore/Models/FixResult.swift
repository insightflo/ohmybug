import Foundation

public struct FixResult: Codable, Sendable {
    public let tool: String
    public let totalFiles: Int
    public let fixedFiles: Int
    public let fixedIssueCount: Int
    public let duration: TimeInterval
    public let details: [FixDetail]

    public init(
        tool: String,
        totalFiles: Int,
        fixedFiles: Int,
        fixedIssueCount: Int,
        duration: TimeInterval,
        details: [FixDetail] = []
    ) {
        self.tool = tool
        self.totalFiles = totalFiles
        self.fixedFiles = fixedFiles
        self.fixedIssueCount = fixedIssueCount
        self.duration = duration
        self.details = details
    }
}

public struct FixDetail: Codable, Sendable {
    public let rule: String
    public let count: Int
    public let description: String

    public init(rule: String, count: Int, description: String) {
        self.rule = rule
        self.count = count
        self.description = description
    }
}
