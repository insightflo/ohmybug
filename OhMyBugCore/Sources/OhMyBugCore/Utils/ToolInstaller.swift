import Foundation

public enum ToolInstaller {
    public static func ensureAvailable(_ tool: String, brewPackage: String? = nil) async throws -> String {
        if let path = await ShellRunner.which(tool) {
            return path
        }

        #if os(Windows)
        throw ToolError.toolNotAvailable(tool: tool)
        #else
        let package = brewPackage ?? tool
        let brewPath = await ShellRunner.which("brew")
        guard brewPath != nil else {
            throw ToolError.homebrewNotInstalled
        }

        let result = try await ShellRunner.runShell("brew install \(package)")
        guard result.succeeded else {
            throw ToolError.installFailed(tool: package, message: result.stderr)
        }

        guard let path = await ShellRunner.which(tool) else {
            throw ToolError.notFoundAfterInstall(tool: tool)
        }
        return path
        #endif
    }

    public static func isInstalled(_ tool: String) async -> Bool {
        await ShellRunner.which(tool) != nil
    }
}

public enum ToolError: LocalizedError {
    case homebrewNotInstalled
    case installFailed(tool: String, message: String)
    case notFoundAfterInstall(tool: String)
    case toolNotAvailable(tool: String)

    public var errorDescription: String? {
        switch self {
        case .homebrewNotInstalled:
            "Homebrew is not installed. Install from https://brew.sh"
        case let .installFailed(tool, message):
            "Failed to install \(tool): \(message)"
        case let .notFoundAfterInstall(tool):
            "\(tool) not found after installation"
        case let .toolNotAvailable(tool):
            "\(tool) is not available. Install it first."
        }
    }
}
