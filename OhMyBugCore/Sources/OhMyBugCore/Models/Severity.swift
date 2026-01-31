import Foundation

public enum Severity: String, Codable, Comparable, CaseIterable, Sendable {
    case critical
    case high
    case medium
    case low
    case info

    public var weight: Int {
        switch self {
        case .critical: 5
        case .high: 4
        case .medium: 3
        case .low: 2
        case .info: 1
        }
    }

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.weight < rhs.weight
    }
}
