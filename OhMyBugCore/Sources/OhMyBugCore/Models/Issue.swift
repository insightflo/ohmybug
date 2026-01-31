import Foundation

public struct Issue: Identifiable, Codable, Sendable {
    public let id: UUID
    public let rule: String
    public let message: String
    public let severity: Severity
    public let filePath: String
    public let line: Int?
    public let column: Int?
    public let scanner: String
    public var isFixed: Bool

    public init(
        id: UUID = UUID(),
        rule: String,
        message: String,
        severity: Severity,
        filePath: String,
        line: Int? = nil,
        column: Int? = nil,
        scanner: String,
        isFixed: Bool = false
    ) {
        self.id = id
        self.rule = rule
        self.message = message
        self.severity = severity
        self.filePath = filePath
        self.line = line
        self.column = column
        self.scanner = scanner
        self.isFixed = isFixed
    }
}
