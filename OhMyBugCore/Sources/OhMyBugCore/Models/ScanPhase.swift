import Foundation

public enum ScanPhase: String, Codable, CaseIterable, Sendable {
    case idle = "Idle"
    case build = "Build"
    case tools = "Tools"
    case scan = "Scan"
    case aiFix = "AI Fix"
    case verify = "Verify"
    case complete = "Complete"

    public var index: Int {
        switch self {
        case .idle: 0
        case .build: 1
        case .tools: 2
        case .scan: 3
        case .aiFix: 4
        case .verify: 5
        case .complete: 6
        }
    }

    public static var activePhases: [ScanPhase] {
        [.build, .tools, .scan, .aiFix, .verify]
    }
}
