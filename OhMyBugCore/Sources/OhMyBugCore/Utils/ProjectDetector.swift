import Foundation

public enum ProjectDetector {
    public static func detect(at path: String) -> ProjectType {
        let fm = FileManager.default
        let hasPackageSwift = fm.fileExists(atPath: "\(path)/Package.swift")
        let hasXcodeproj = (try? fm.contentsOfDirectory(atPath: path))?.contains { $0.hasSuffix(".xcodeproj") } ?? false
        let hasXcworkspace = (try? fm.contentsOfDirectory(atPath: path))?.contains { $0.hasSuffix(".xcworkspace") } ?? false
        let hasPackageJSON = fm.fileExists(atPath: "\(path)/package.json")
        let hasTSConfig = fm.fileExists(atPath: "\(path)/tsconfig.json")
        let hasPubspec = fm.fileExists(atPath: "\(path)/pubspec.yaml")
        let hasRequirements = fm.fileExists(atPath: "\(path)/requirements.txt")
        let hasPyproject = fm.fileExists(atPath: "\(path)/pyproject.toml")
        let hasSetupPy = fm.fileExists(atPath: "\(path)/setup.py")

        let isSwift = hasPackageSwift || hasXcodeproj || hasXcworkspace
        let isJS = hasPackageJSON || hasTSConfig
        let isFlutter = hasPubspec
        let isPython = hasRequirements || hasPyproject || hasSetupPy

        let typeCount = [isSwift, isJS, isFlutter, isPython].filter { $0 }.count
        if typeCount > 1 { return .mixed }

        if isFlutter { return .flutter }
        if isSwift { return .swift }
        if isJS { return .javascript }
        if isPython { return .python }
        return .auto
    }

    public static func isPythonProject(at path: String) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: "\(path)/requirements.txt") ||
               fm.fileExists(atPath: "\(path)/pyproject.toml") ||
               fm.fileExists(atPath: "\(path)/setup.py")
    }

    public static func findSwiftFiles(at path: String) -> [String] {
        findFiles(at: path, withExtension: "swift")
    }

    public static func findJSFiles(at path: String) -> [String] {
        findFiles(at: path, withExtensions: ["js", "jsx", "ts", "tsx"])
    }

    public static func findDartFiles(at path: String) -> [String] {
        findFiles(at: path, withExtension: "dart")
    }

    public static func findPythonFiles(at path: String) -> [String] {
        findFiles(at: path, withExtension: "py")
    }

    private static func findFiles(at path: String, withExtension ext: String) -> [String] {
        findFiles(at: path, withExtensions: [ext])
    }

    private static func findFiles(at path: String, withExtensions extensions: [String]) -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: path) else { return [] }

        var files: [String] = []
        let skipDirs = Set([".build", "node_modules", ".git", "Pods", "DerivedData", "build", ".dart_tool", ".pub-cache", "__pycache__", ".venv", "venv", ".tox", ".mypy_cache", ".pytest_cache", ".ruff_cache", "site-packages"])

        while let file = enumerator.nextObject() as? String {
            let components = file.components(separatedBy: "/")
            if components.contains(where: { skipDirs.contains($0) }) {
                continue
            }
            let ext = (file as NSString).pathExtension
            if extensions.contains(ext) {
                files.append("\(path)/\(file)")
            }
        }
        return files
    }
}
