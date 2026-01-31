# OhMyBug

Automatically scan and fix code quality issues across Swift, JavaScript/TypeScript, and Flutter/Dart projects.

**CLI**: macOS + Windows | **GUI App**: macOS only

## Features

- **Multi-language support** — Swift (SwiftLint, SwiftFormat), JS/TS (ESLint, Prettier), Dart/Flutter (dart analyze, dart format)
- **Build verification** — Checks your project builds before and after fixes
- **AI-powered fixes** — Uses GLM (CodeGeeX-4) for issues that tools can't auto-fix
- **Safe by default** — Creates file backups before any fix. Auto-rollback if build fails after fixing
- **2-phase workflow** — Scan → Review → Fix. No surprise changes
- **Cross-platform CLI** — Works on macOS and Windows

## Platform Support

| Feature | macOS | Windows |
|---------|-------|---------|
| CLI | ✅ | ✅ |
| SwiftUI App | ✅ | ❌ |
| Swift scanning (SwiftLint, SwiftFormat) | ✅ | ❌ |
| JS/TS scanning (ESLint, Prettier) | ✅ | ✅ |
| Dart/Flutter scanning | ✅ | ✅ |
| AI-powered fixes (GLM) | ✅ | ✅ |

> **Note**: Swift tools are not available on Windows, so Swift-related scanners are automatically disabled.

## Requirements

### macOS
- macOS 14.0+
- Swift 5.9+
- Xcode 15+ (or Swift toolchain)

### Windows
- Windows 10+
- [Swift for Windows](https://www.swift.org/download/) 5.9+
- Node.js (for ESLint/Prettier)
- Flutter SDK (for Dart/Flutter projects)

### Optional Tools (auto-detected)

| Tool | For | macOS Install | Windows Install |
|------|-----|---------------|-----------------|
| SwiftLint | Swift linting | `brew install swiftlint` | N/A (macOS only) |
| SwiftFormat | Swift formatting | `brew install swiftformat` | N/A (macOS only) |
| Node.js + npx | JS/TS linting & formatting | `brew install node` | [nodejs.org](https://nodejs.org) |
| Flutter SDK | Dart/Flutter analysis | [flutter.dev](https://flutter.dev) | [flutter.dev](https://flutter.dev) |

OhMyBug only runs scanners for tools that are installed. No tool = scanner skipped.

## Installation

### CLI (macOS)

```bash
git clone https://github.com/insightflo/ohmybug.git
cd ohmybug/OhMyBugCore
swift build -c release

# The binary is at:
# .build/release/ohmybug

# Optional: copy to PATH
cp .build/release/ohmybug /usr/local/bin/
```

### CLI (Windows)

```powershell
git clone https://github.com/insightflo/ohmybug.git
cd ohmybug\OhMyBugCore
swift build -c release

# The binary is at:
# .build\release\ohmybug.exe
```

### macOS App

```bash
cd ohmybug/OhMyBugApp
swift build
swift run OhMyBugApp
```

Or open `OhMyBugApp/Package.swift` in Xcode and run.

## Usage

### CLI

```bash
# Scan only (default)
ohmybug check /path/to/project --verbose

# Scan + auto-fix (creates backup, rollback on build failure)
ohmybug check /path/to/project --fix

# Scan + fix with AI (GLM CodeGeeX-4)
ohmybug check /path/to/project --fix --glm-key YOUR_API_KEY

# Output formats: text (default), markdown, json
ohmybug check /path/to/project --format json
```

### macOS App

1. Launch the app
2. Drag & drop a project folder
3. Click **Scan Project** — review the report
4. Click **Apply Fixes** — backup is created automatically
5. If something breaks → click **Rollback**

### GLM API Key

OhMyBug uses [Zhipu AI's CodeGeeX-4](https://open.bigmodel.cn/) for AI-powered fixes. The API key is:
- **CLI**: passed via `--glm-key` flag (never stored)
- **App**: entered in the Settings panel (stored in UserDefaults, never leaves your machine)

## Architecture

```
ohmybug/
├── OhMyBugCore/             # SPM library + CLI (cross-platform)
│   ├── Sources/
│   │   ├── OhMyBugCore/
│   │   │   ├── Models/      # Issue, ScanResult, FixResult, PipelineReport
│   │   │   ├── Scanners/    # SwiftLint, SwiftFormat, ESLint, Prettier, Dart, Flutter, BuildChecker
│   │   │   ├── Fixers/      # LLMClient (GLM), AIFixer
│   │   │   ├── Pipeline/    # PipelineEngine (actor), scanner registration
│   │   │   └── Utils/       # ShellRunner, ToolInstaller, ProjectDetector, BackupManager, Platform
│   │   └── OhMyBugCLI/      # CLI entry point
│   └── Tests/
└── OhMyBugApp/              # SwiftUI macOS app (macOS only)
    └── OhMyBugApp/
        ├── Views/           # ProjectDropZone, PhaseIndicator, LogView, ResultsDashboard, ScanReportView, SettingsPanel
        ├── ViewModels/      # AppViewModel, AppSettings
        └── Theme.swift      # Dark theme
```

### How it works

1. **Detect** — `ProjectDetector` identifies project type (Swift / JS / Flutter / mixed)
2. **Register** — `PipelineEngine` registers relevant scanners for the detected type
3. **Scan** — Each scanner runs its tool and returns `ScanResult` with issues
4. **Report** — Issues aggregated into `ScanReport` (by severity, scanner, rule, file)
5. **Fix** — Tool-based auto-fix first, then AI fixer for remaining issues
6. **Verify** — Re-scan + build check after fixes
7. **Rollback** — If build fails, `BackupManager` restores all files

### Key design decisions

- `PipelineEngine` is a Swift `actor` for safe concurrency
- Views use `@Observable` (Swift 5.9 Observation framework, not ObservableObject)
- BuildChecker searches subdirectories for buildable targets (Package.swift, pubspec.yaml, .xcodeproj)
- All shell commands run via `ShellRunner` with OS-specific shell detection
- Platform-specific code uses `#if os(Windows)` / `#if os(macOS)` conditionals

## License

MIT
