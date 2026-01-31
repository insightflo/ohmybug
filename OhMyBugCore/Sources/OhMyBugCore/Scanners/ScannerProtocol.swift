import Foundation

public protocol Scanner: Sendable {
    var name: String { get }
    var supportedProjectTypes: [ProjectType] { get }

    func isAvailable() async -> Bool
    func scan(projectPath: String) async throws -> ScanResult
}

public protocol Fixer: Sendable {
    var name: String { get }

    func isAvailable() async -> Bool
    func fix(projectPath: String) async throws -> FixResult
}

public protocol ScannerFixer: Scanner, Fixer {}
