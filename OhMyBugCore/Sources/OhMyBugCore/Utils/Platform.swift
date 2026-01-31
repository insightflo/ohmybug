import Foundation

public enum Platform {
    case macOS
    case windows
    case linux
    case unknown

    public static var current: Platform {
        #if os(macOS)
        return .macOS
        #elseif os(Windows)
        return .windows
        #elseif os(Linux)
        return .linux
        #else
        return .unknown
        #endif
    }

    public static var isWindows: Bool {
        current == .windows
    }

    public static var isMacOS: Bool {
        current == .macOS
    }

    public static var isUnix: Bool {
        current == .macOS || current == .linux
    }

    public static var shellPath: String {
        #if os(Windows)
        return "cmd.exe"
        #else
        return "/bin/bash"
        #endif
    }

    public static var shellArguments: (String) -> [String] {
        #if os(Windows)
        return { command in ["/c", command] }
        #else
        return { command in ["-c", command] }
        #endif
    }

    public static var whichCommand: String {
        #if os(Windows)
        return "where"
        #else
        return "which"
        #endif
    }
}
