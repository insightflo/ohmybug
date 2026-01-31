import Foundation

public enum JSFramework: String, CaseIterable, Sendable {
    case react
    case nextjs
    case vue
    case nuxtjs
    case express
    case nestjs
    case vanilla

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

    public var eslintPlugins: [String] {
        switch self {
        case .react:
            return ["eslint-plugin-react", "eslint-plugin-react-hooks"]
        case .nextjs:
            return ["eslint-plugin-react", "eslint-plugin-react-hooks", "@next/eslint-plugin-next"]
        case .vue:
            return ["eslint-plugin-vue"]
        case .nuxtjs:
            return ["eslint-plugin-vue", "@nuxt/eslint-plugin"]
        case .express, .nestjs, .vanilla:
            return []
        }
    }
}

public enum FrameworkDetector {
    public static func detect(at projectPath: String) -> [JSFramework] {
        guard let packageJson = readPackageJson(at: projectPath) else {
            return [.vanilla]
        }

        var frameworks: [JSFramework] = []
        let allDeps = mergeDependencies(packageJson)

        if allDeps.contains("next") {
            frameworks.append(.nextjs)
        } else if allDeps.contains("react") {
            frameworks.append(.react)
        }

        if allDeps.contains("nuxt") {
            frameworks.append(.nuxtjs)
        } else if allDeps.contains("vue") {
            frameworks.append(.vue)
        }

        if allDeps.contains("@nestjs/core") {
            frameworks.append(.nestjs)
        } else if allDeps.contains("express") {
            frameworks.append(.express)
        }

        return frameworks.isEmpty ? [.vanilla] : frameworks
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

    public static func hasRequiredPlugins(at projectPath: String, for framework: JSFramework) -> Bool {
        guard let packageJson = readPackageJson(at: projectPath) else {
            return false
        }

        let allDeps = mergeDependencies(packageJson)
        let requiredPlugins = framework.eslintPlugins

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
}
