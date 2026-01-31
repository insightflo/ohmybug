# OhMyBug

Automatically scan and fix code quality issues across Swift, JavaScript/TypeScript, and Flutter/Dart projects.

macOS CLI + native SwiftUI app.

## Features

- **Multi-language support** — Swift (SwiftLint, SwiftFormat), JS/TS (ESLint, Prettier), Dart/Flutter (dart analyze, dart format)
- **Build verification** — Checks your project builds before and after fixes
- **AI-powered fixes** — Uses GLM (CodeGeeX-4) for issues that tools can't auto-fix
- **Safe by default** — Creates file backups before any fix. Auto-rollback if build fails after fixing
- **2-phase workflow** — Scan → Review → Fix. No surprise changes
- **CLI + GUI** — Use from terminal or the native macOS app

## Requirements

- macOS 14.0+
- Swift 5.9+
- Xcode 15+ (or Swift toolchain)

### Optional (auto-detected)

| Tool | For | Install |
|------|-----|---------|
| SwiftLint | Swift linting | `brew install swiftlint` |
| SwiftFormat | Swift formatting | `brew install swiftformat` |
| Node.js + npx | JS/TS linting & formatting | `brew install node` |
| Flutter SDK | Dart/Flutter analysis | [flutter.dev](https://flutter.dev) |

OhMyBug only runs scanners for tools that are installed. No tool = scanner skipped.

## Installation

### CLI

```bash
git clone https://github.com/your-username/ohmybug.git
cd ohmybug/OhMyBugCore
swift build -c release

# The binary is at:
# .build/release/ohmybug

# Optional: copy to PATH
cp .build/release/ohmybug /usr/local/bin/
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
├── OhMyBugCore/             # SPM library + CLI
│   ├── Sources/
│   │   ├── OhMyBugCore/
│   │   │   ├── Models/      # Issue, ScanResult, FixResult, PipelineReport
│   │   │   ├── Scanners/    # SwiftLint, SwiftFormat, ESLint, Prettier, Dart, Flutter, BuildChecker
│   │   │   ├── Fixers/      # LLMClient (GLM), AIFixer
│   │   │   ├── Pipeline/    # PipelineEngine (actor), scanner registration
│   │   │   └── Utils/       # ShellRunner, ToolInstaller, ProjectDetector, BackupManager
│   │   └── OhMyBugCLI/      # CLI entry point
│   └── Tests/
└── OhMyBugApp/              # SwiftUI macOS app
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
- All shell commands run via `ShellRunner` with configurable working directory

## License

MIT
