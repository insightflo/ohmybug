import Foundation

public enum SupportStatus: Sendable {
    case supported
    case unsupportedVersion(detected: String, maxKnown: String)
    case unsupportedPlatform(platform: UnsupportedPlatform)
    case partialSupport(reason: String)
}

public enum UnsupportedPlatform: String, Sendable {
    case androidNative = "Android Native"
    case iosObjectiveC = "iOS Objective-C"
    case kotlin = "Kotlin"
    case java = "Java"
    case rust = "Rust"
    case go = "Go"
    case ruby = "Ruby"
    case php = "PHP"
    case csharp = "C#/.NET"
    case cpp = "C/C++"

    public var alternativeTools: [String] {
        switch self {
        case .androidNative:
            return ["Android Lint (built-in)", "detekt (Kotlin)", "ktlint"]
        case .iosObjectiveC:
            return ["Clang Static Analyzer", "OCLint", "Infer"]
        case .kotlin:
            return ["detekt", "ktlint", "Android Lint"]
        case .java:
            return ["Checkstyle", "PMD", "SpotBugs", "Error Prone"]
        case .rust:
            return ["clippy", "rustfmt"]
        case .go:
            return ["golangci-lint", "go vet", "staticcheck"]
        case .ruby:
            return ["RuboCop", "Reek", "Brakeman"]
        case .php:
            return ["PHP_CodeSniffer", "PHPStan", "Psalm"]
        case .csharp:
            return ["Roslyn Analyzers", "StyleCop", "SonarQube"]
        case .cpp:
            return ["clang-tidy", "cppcheck", "cpplint"]
        }
    }

    public var docsUrl: String? {
        switch self {
        case .androidNative:
            return "https://developer.android.com/studio/write/lint"
        case .kotlin:
            return "https://detekt.dev/"
        case .rust:
            return "https://rust-lang.github.io/rust-clippy/"
        case .go:
            return "https://golangci-lint.run/"
        default:
            return nil
        }
    }
}

public struct SetupGuidance: Sendable {
    public let status: SupportStatus
    public let framework: String?
    public let message: String
    public let actions: [String]
    public let docsUrl: String?

    public var isActionRequired: Bool {
        switch status {
        case .supported:
            return false
        default:
            return true
        }
    }

    public var severityIcon: String {
        switch status {
        case .supported:
            return "✅"
        case .unsupportedVersion:
            return "⚠️"
        case .unsupportedPlatform:
            return "🚫"
        case .partialSupport:
            return "⚡"
        }
    }
}

public enum SetupGuide {
    private static let knownJSVersions: [String: (max: Int, docsUrl: String)] = [
        "vue": (max: 3, docsUrl: "https://eslint.vuejs.org/user-guide/"),
        "nuxt": (max: 3, docsUrl: "https://nuxt.com/docs/guide/concepts/eslint"),
        "react": (max: 19, docsUrl: "https://react.dev/learn/editor-setup#linting"),
        "next": (max: 15, docsUrl: "https://nextjs.org/docs/app/building-your-application/configuring/eslint"),
        "express": (max: 5, docsUrl: "https://expressjs.com/"),
        "@nestjs/core": (max: 10, docsUrl: "https://docs.nestjs.com/")
    ]

    private static let knownPythonVersions: [String: (max: Int, docsUrl: String)] = [
        "django": (max: 5, docsUrl: "https://docs.djangoproject.com/"),
        "flask": (max: 3, docsUrl: "https://flask.palletsprojects.com/"),
        "fastapi": (max: 1, docsUrl: "https://fastapi.tiangolo.com/"),
        "pyramid": (max: 2, docsUrl: "https://trypyramid.com/"),
        "tornado": (max: 6, docsUrl: "https://www.tornadoweb.org/")
    ]

    public static func analyze(projectPath: String) -> [SetupGuidance] {
        var guidances: [SetupGuidance] = []

        let unsupportedPlatforms = detectUnsupportedPlatforms(at: projectPath)
        for platform in unsupportedPlatforms {
            guidances.append(createPlatformGuidance(platform))
        }

        let jsFrameworkInfos = FrameworkDetector.detectWithVersions(at: projectPath)
        for info in jsFrameworkInfos where info.framework != .vanilla {
            if let guidance = checkJSVersionSupport(info) {
                guidances.append(guidance)
            }
        }

        let pyFrameworkInfos = PythonFrameworkDetector.detectWithVersions(at: projectPath)
        for info in pyFrameworkInfos where info.framework != .vanilla {
            if let guidance = checkPythonVersionSupport(info) {
                guidances.append(guidance)
            }
        }

        return guidances
    }

    public static func detectUnsupportedPlatforms(at projectPath: String) -> [UnsupportedPlatform] {
        let fm = FileManager.default
        var platforms: [UnsupportedPlatform] = []

        if fm.fileExists(atPath: "\(projectPath)/build.gradle") ||
           fm.fileExists(atPath: "\(projectPath)/build.gradle.kts") ||
           fm.fileExists(atPath: "\(projectPath)/app/build.gradle") ||
           fm.fileExists(atPath: "\(projectPath)/app/build.gradle.kts") {
            platforms.append(.androidNative)
        }

        let hasKotlinFiles = (try? fm.contentsOfDirectory(atPath: projectPath))?
            .contains { $0.hasSuffix(".kt") || $0.hasSuffix(".kts") } ?? false
        if hasKotlinFiles && !platforms.contains(.androidNative) {
            platforms.append(.kotlin)
        }

        let hasJavaFiles = (try? fm.contentsOfDirectory(atPath: projectPath))?
            .contains { $0.hasSuffix(".java") } ?? false
        if hasJavaFiles && !platforms.contains(.androidNative) {
            platforms.append(.java)
        }

        if fm.fileExists(atPath: "\(projectPath)/Cargo.toml") {
            platforms.append(.rust)
        }

        if fm.fileExists(atPath: "\(projectPath)/go.mod") {
            platforms.append(.go)
        }

        if fm.fileExists(atPath: "\(projectPath)/Gemfile") {
            platforms.append(.ruby)
        }

        if fm.fileExists(atPath: "\(projectPath)/composer.json") {
            platforms.append(.php)
        }

        let hasObjCFiles = (try? fm.contentsOfDirectory(atPath: projectPath))?
            .contains { $0.hasSuffix(".m") || $0.hasSuffix(".mm") } ?? false
        if hasObjCFiles {
            platforms.append(.iosObjectiveC)
        }

        let hasCppFiles = (try? fm.contentsOfDirectory(atPath: projectPath))?.contains(where: { $0.hasSuffix(".cpp") || $0.hasSuffix(".c") || $0.hasSuffix(".h") }) ?? false
        if fm.fileExists(atPath: "\(projectPath)/CMakeLists.txt") || hasCppFiles {
            if !platforms.contains(.iosObjectiveC) {
                platforms.append(.cpp)
            }
        }

        return platforms
    }

    private static func checkJSVersionSupport(_ info: FrameworkInfo) -> SetupGuidance? {
        guard let majorVersion = info.majorVersion else { return nil }

        let packageName = info.framework.packageName
        guard let known = knownJSVersions[packageName] else { return nil }

        if majorVersion > known.max {
            return SetupGuidance(
                status: .unsupportedVersion(detected: info.version ?? "\(majorVersion)", maxKnown: "\(known.max)"),
                framework: info.displayName,
                message: "\(info.displayName) v\(majorVersion) detected. OhMyBug supports up to v\(known.max).",
                actions: [
                    "Current config may still work (using v\(known.max) settings)",
                    "Check official docs for v\(majorVersion) ESLint setup",
                    "Or add custom config to .ohmybugrc.json"
                ],
                docsUrl: known.docsUrl
            )
        }

        return nil
    }

    private static func checkPythonVersionSupport(_ info: PythonFrameworkInfo) -> SetupGuidance? {
        guard let majorVersion = info.majorVersion else { return nil }

        let packageName = info.framework.rawValue
        guard let known = knownPythonVersions[packageName] else { return nil }

        if majorVersion > known.max {
            return SetupGuidance(
                status: .unsupportedVersion(detected: info.version ?? "\(majorVersion)", maxKnown: "\(known.max)"),
                framework: info.displayName,
                message: "\(info.displayName) v\(majorVersion) detected. OhMyBug supports up to v\(known.max).",
                actions: [
                    "Current config may still work (using v\(known.max) settings)",
                    "Check official docs for v\(majorVersion) Ruff setup",
                    "Or add custom config to ruff.toml"
                ],
                docsUrl: known.docsUrl
            )
        }

        return nil
    }

    private static func createPlatformGuidance(_ platform: UnsupportedPlatform) -> SetupGuidance {
        let tools = platform.alternativeTools
        var actions = ["OhMyBug does not support \(platform.rawValue) projects"]

        if !tools.isEmpty {
            actions.append("Recommended tools: \(tools.joined(separator: ", "))")
        }

        if let url = platform.docsUrl {
            actions.append("See: \(url)")
        }

        return SetupGuidance(
            status: .unsupportedPlatform(platform: platform),
            framework: nil,
            message: "\(platform.rawValue) project detected",
            actions: actions,
            docsUrl: platform.docsUrl
        )
    }
}

fileprivate extension JSFramework {
    var packageName: String {
        switch self {
        case .react: return "react"
        case .nextjs: return "next"
        case .vue: return "vue"
        case .nuxtjs: return "nuxt"
        case .express: return "express"
        case .nestjs: return "@nestjs/core"
        case .vanilla: return ""
        }
    }
}
