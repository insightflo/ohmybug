import Foundation

public struct LogEntry: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let message: String
    public let source: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel = .info,
        message: String,
        source: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.source = source
    }
}

public enum LogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
    case success
}
