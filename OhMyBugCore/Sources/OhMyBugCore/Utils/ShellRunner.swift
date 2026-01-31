import Foundation

public struct ShellOutput: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public var succeeded: Bool {
        exitCode == 0
    }
}

public enum ShellRunner {
    public static func run(
        _ command: String,
        arguments: [String] = [],
        workingDirectory: String? = nil
    ) async throws -> ShellOutput {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments

            if let workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
            }

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let output = ShellOutput(
                    exitCode: process.terminationStatus,
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? ""
                )
                continuation.resume(returning: output)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public static func which(_ tool: String) async -> String? {
        #if os(Windows)
        guard let output = try? await runShell("where \(tool)") else {
            return nil
        }
        let path = output.stdout.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces)
        return (path?.isEmpty ?? true) ? nil : path
        #else
        guard let output = try? await run("/usr/bin/which", arguments: [tool]) else {
            return nil
        }
        let path = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
        #endif
    }

    public static func runShell(_ command: String, workingDirectory: String? = nil) async throws -> ShellOutput {
        #if os(Windows)
        try await run("cmd.exe", arguments: ["/c", command], workingDirectory: workingDirectory)
        #else
        try await run("/bin/bash", arguments: ["-c", command], workingDirectory: workingDirectory)
        #endif
    }
}
