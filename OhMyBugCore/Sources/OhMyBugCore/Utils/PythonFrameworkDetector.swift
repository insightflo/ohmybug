import Foundation

public enum PythonFramework: String, CaseIterable, Sendable {
    case django
    case flask
    case fastapi
    case pyramid
    case tornado
    case vanilla

    public var displayName: String {
        switch self {
        case .django: return "Django"
        case .flask: return "Flask"
        case .fastapi: return "FastAPI"
        case .pyramid: return "Pyramid"
        case .tornado: return "Tornado"
        case .vanilla: return "Python"
        }
    }

    public var ruffPlugins: [String] {
        switch self {
        case .django:
            return ["DJ"]
        case .flask, .fastapi, .pyramid, .tornado, .vanilla:
            return []
        }
    }
}

public struct PythonFrameworkInfo: Sendable {
    public let framework: PythonFramework
    public let version: String?
    public let majorVersion: Int?

    public var displayName: String {
        var name = framework.displayName
        if let version = version {
            name += " \(version)"
        }
        return name
    }
}

public enum PythonFrameworkDetector {
    public static func detectWithVersions(at projectPath: String) -> [PythonFrameworkInfo] {
        var frameworks: [PythonFrameworkInfo] = []

        let requirementsDeps = parseRequirements(at: projectPath)
        let pyprojectDeps = parsePyproject(at: projectPath)
        let allDeps = requirementsDeps.merging(pyprojectDeps) { _, new in new }

        if let djangoVersion = allDeps["django"] ?? allDeps["Django"] {
            frameworks.append(PythonFrameworkInfo(
                framework: .django,
                version: cleanVersion(djangoVersion),
                majorVersion: parseMajorVersion(djangoVersion)
            ))
        }

        if let flaskVersion = allDeps["flask"] ?? allDeps["Flask"] {
            frameworks.append(PythonFrameworkInfo(
                framework: .flask,
                version: cleanVersion(flaskVersion),
                majorVersion: parseMajorVersion(flaskVersion)
            ))
        }

        if let fastapiVersion = allDeps["fastapi"] ?? allDeps["FastAPI"] {
            frameworks.append(PythonFrameworkInfo(
                framework: .fastapi,
                version: cleanVersion(fastapiVersion),
                majorVersion: parseMajorVersion(fastapiVersion)
            ))
        }

        if let pyramidVersion = allDeps["pyramid"] ?? allDeps["Pyramid"] {
            frameworks.append(PythonFrameworkInfo(
                framework: .pyramid,
                version: cleanVersion(pyramidVersion),
                majorVersion: parseMajorVersion(pyramidVersion)
            ))
        }

        if let tornadoVersion = allDeps["tornado"] ?? allDeps["Tornado"] {
            frameworks.append(PythonFrameworkInfo(
                framework: .tornado,
                version: cleanVersion(tornadoVersion),
                majorVersion: parseMajorVersion(tornadoVersion)
            ))
        }

        if frameworks.isEmpty {
            return [PythonFrameworkInfo(framework: .vanilla, version: nil, majorVersion: nil)]
        }

        return frameworks
    }

    public static func detect(at projectPath: String) -> [PythonFramework] {
        detectWithVersions(at: projectPath).map(\.framework)
    }

    private static func parseRequirements(at projectPath: String) -> [String: String] {
        let path = "\(projectPath)/requirements.txt"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return [:]
        }

        var deps: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("-") else { continue }

            let parts = trimmed.components(separatedBy: CharacterSet(charactersIn: "=<>~!"))
            if let packageName = parts.first?.trimmingCharacters(in: .whitespaces), !packageName.isEmpty {
                let version = parts.count > 1 ? parts.last?.trimmingCharacters(in: .whitespaces) : nil
                deps[packageName.lowercased()] = version ?? "*"
            }
        }

        return deps
    }

    private static func parsePyproject(at projectPath: String) -> [String: String] {
        let path = "\(projectPath)/pyproject.toml"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return [:]
        }

        var deps: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
        var inDependencies = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("[project.dependencies]") || trimmed.contains("[tool.poetry.dependencies]") {
                inDependencies = true
                continue
            }

            if trimmed.hasPrefix("[") && inDependencies {
                inDependencies = false
                continue
            }

            if inDependencies {
                if trimmed.contains("=") {
                    let parts = trimmed.components(separatedBy: "=")
                    if let name = parts.first?.trimmingCharacters(in: CharacterSet(charactersIn: "\" '")),
                       let version = parts.last?.trimmingCharacters(in: CharacterSet(charactersIn: "\" '")) {
                        deps[name.lowercased()] = version
                    }
                } else if trimmed.hasPrefix("\"") || trimmed.hasPrefix("'") {
                    let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "\"',"))
                    let parts = cleaned.components(separatedBy: CharacterSet(charactersIn: "=<>~!"))
                    if let name = parts.first?.trimmingCharacters(in: .whitespaces) {
                        let version = parts.count > 1 ? parts.last?.trimmingCharacters(in: .whitespaces) : nil
                        deps[name.lowercased()] = version ?? "*"
                    }
                }
            }
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
            .replacingOccurrences(of: "==", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func parseMajorVersion(_ version: String) -> Int? {
        let cleaned = cleanVersion(version)
        let components = cleaned.components(separatedBy: ".")
        guard let first = components.first else { return nil }
        return Int(first)
    }
}
