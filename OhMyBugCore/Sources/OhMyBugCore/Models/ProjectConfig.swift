import Foundation

public struct ProjectConfig: Codable, Sendable {
    public let projectPath: String
    public let projectType: ProjectType
    public var autoApplyFixes: Bool
    public var runBuildCheck: Bool
    public var glmAPIKey: String?

    public init(
        projectPath: String,
        projectType: ProjectType = .auto,
        autoApplyFixes: Bool = true,
        runBuildCheck: Bool = true,
        glmAPIKey: String? = nil
    ) {
        self.projectPath = projectPath
        self.projectType = projectType
        self.autoApplyFixes = autoApplyFixes
        self.runBuildCheck = runBuildCheck
        self.glmAPIKey = glmAPIKey
    }
}

public enum ProjectType: String, Codable, Sendable {
    case swift
    case javascript
    case flutter
    case mixed
    case auto
}
