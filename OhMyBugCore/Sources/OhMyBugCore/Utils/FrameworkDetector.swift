import Foundation

public enum JSFramework: String, CaseIterable, Sendable {
    case react
    case nextjs
    case vue
    case nuxtjs
    case express
    case nestjs
    case vanilla
}

public struct FrameworkInfo: Sendable {
    public let framework: JSFramework
    public let version: String?
    public let majorVersion: Int?

    public var displayName: String {
        var name = framework.displayName
        if let version = version {
            name += " \(version)"
        }
        return name
    }

    public var eslintConfig: String? {
        switch framework {
        case .vue:
            guard let major = majorVersion else { return "plugin:vue/recommended" }
            return major >= 3 ? "plugin:vue/vue3-recommended" : "plugin:vue/recommended"
        case .react:
            return "plugin:react/recommended"
        case .nextjs:
            return "plugin:@next/next/recommended"
        case .nuxtjs:
            guard let major = majorVersion else { return "@nuxt/eslint-config" }
            return major >= 3 ? "@nuxt/eslint-config" : "@nuxtjs/eslint-config"
        default:
            return nil
        }
    }

    public var eslintPlugins: [String] {
        switch framework {
        case .react:
            return ["eslint-plugin-react", "eslint-plugin-react-hooks"]
        case .nextjs:
            return ["eslint-plugin-react", "eslint-plugin-react-hooks", "@next/eslint-plugin-next"]
        case .vue:
            return ["eslint-plugin-vue"]
        case .nuxtjs:
            if let major = majorVersion, major >= 3 {
                return ["@nuxt/eslint-config"]
            }
            return ["eslint-plugin-vue", "@nuxtjs/eslint-config"]
        case .express, .nestjs, .vanilla:
            return []
        }
    }
}

extension JSFramework {
    public var displayName: String {
        switch self {
        case .react: return "React"
        case .nextjs: return "Next.js"
        case .vue: return "Vue"
        case .nuxtjs: return "Nuxt.js"
        case .express: return "Express.js"
        case .nestjs: return "NestJS"
        case .vanilla: return "Vanilla JS/TS"
        }
    }

    fileprivate var packageName: String {
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

public enum FrameworkDetector {
    public static func detectWithVersions(at projectPath: String) -> [FrameworkInfo] {
        guard let packageJson = readPackageJson(at: projectPath) else {
            return [FrameworkInfo(framework: .vanilla, version: nil, majorVersion: nil)]
        }

        let deps = getDependenciesWithVersions(packageJson)
        var frameworks: [FrameworkInfo] = []

        if let nextVersion = deps["next"] {
            let info = FrameworkInfo(
                framework: .nextjs,
                version: cleanVersion(nextVersion),
                majorVersion: parseMajorVersion(nextVersion)
            )
            frameworks.append(info)
        } else if let reactVersion = deps["react"] {
            let info = FrameworkInfo(
                framework: .react,
                version: cleanVersion(reactVersion),
                majorVersion: parseMajorVersion(reactVersion)
            )
            frameworks.append(info)
        }

        if let nuxtVersion = deps["nuxt"] {
            let info = FrameworkInfo(
                framework: .nuxtjs,
                version: cleanVersion(nuxtVersion),
                majorVersion: parseMajorVersion(nuxtVersion)
            )
            frameworks.append(info)
        } else if let vueVersion = deps["vue"] {
            let info = FrameworkInfo(
                framework: .vue,
                version: cleanVersion(vueVersion),
                majorVersion: parseMajorVersion(vueVersion)
            )
            frameworks.append(info)
        }

        if let nestVersion = deps["@nestjs/core"] {
            let info = FrameworkInfo(
                framework: .nestjs,
                version: cleanVersion(nestVersion),
                majorVersion: parseMajorVersion(nestVersion)
            )
            frameworks.append(info)
        } else if let expressVersion = deps["express"] {
            let info = FrameworkInfo(
                framework: .express,
                version: cleanVersion(expressVersion),
                majorVersion: parseMajorVersion(expressVersion)
            )
            frameworks.append(info)
        }

        if frameworks.isEmpty {
            return [FrameworkInfo(framework: .vanilla, version: nil, majorVersion: nil)]
        }

        return frameworks
    }

    public static func detect(at projectPath: String) -> [JSFramework] {
        detectWithVersions(at: projectPath).map(\.framework)
    }

    public static func hasESLintConfig(at projectPath: String) -> Bool {
        let fm = FileManager.default
        let configFiles = [
            "eslint.config.js",
            "eslint.config.mjs",
            "eslint.config.cjs",
            ".eslintrc",
            ".eslintrc.js",
            ".eslintrc.cjs",
            ".eslintrc.json",
            ".eslintrc.yaml",
            ".eslintrc.yml"
        ]

        for file in configFiles {
            if fm.fileExists(atPath: "\(projectPath)/\(file)") {
                return true
            }
        }

        if let packageJson = readPackageJson(at: projectPath),
           packageJson["eslintConfig"] != nil {
            return true
        }

        return false
    }

    public static func hasRequiredPlugins(at projectPath: String, for frameworkInfo: FrameworkInfo) -> Bool {
        guard let packageJson = readPackageJson(at: projectPath) else {
            return false
        }

        let allDeps = mergeDependencies(packageJson)
        let requiredPlugins = frameworkInfo.eslintPlugins

        return requiredPlugins.allSatisfy { allDeps.contains($0) }
    }

    private static func readPackageJson(at projectPath: String) -> [String: Any]? {
        let path = "\(projectPath)/package.json"
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json
    }

    private static func getDependenciesWithVersions(_ packageJson: [String: Any]) -> [String: String] {
        var deps: [String: String] = [:]

        if let dependencies = packageJson["dependencies"] as? [String: String] {
            deps.merge(dependencies) { _, new in new }
        }
        if let devDependencies = packageJson["devDependencies"] as? [String: String] {
            deps.merge(devDependencies) { _, new in new }
        }

        return deps
    }

    private static func mergeDependencies(_ packageJson: [String: Any]) -> Set<String> {
        var deps = Set<String>()

        if let dependencies = packageJson["dependencies"] as? [String: Any] {
            deps.formUnion(dependencies.keys)
        }
        if let devDependencies = packageJson["devDependencies"] as? [String: Any] {
            deps.formUnion(devDependencies.keys)
        }

        return deps
    }

    private static func cleanVersion(_ version: String) -> String {
        version
            .replacingOccurrences(of: "^", with: "")
            .replacingOccurrences(of: "~", with: "")
            .replacingOccurrences(of: ">=", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "<=", with: "")
            .replacingOccurrences(of: "<", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func parseMajorVersion(_ version: String) -> Int? {
        let cleaned = cleanVersion(version)
        let components = cleaned.components(separatedBy: ".")
        guard let first = components.first else { return nil }
        return Int(first)
    }
}
