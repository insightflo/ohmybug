# OhMyBug

Swift, JavaScript/TypeScript, Flutter/Dart, Python 프로젝트의 코드 품질 이슈를 자동으로 스캔하고 수정합니다.

**CLI**: macOS + Windows | **GUI 앱**: macOS (SwiftUI) + Windows (Tauri)

## 주요 기능

- **멀티 언어 지원** — Swift (SwiftLint, SwiftFormat), JS/TS (ESLint, Prettier), Dart/Flutter (dart analyze, dart format), Python (Ruff)
- **프레임워크 감지** — React, Next.js, Vue, Nuxt.js, Express, NestJS 자동 감지 및 ESLint 설정 확인
- **빌드 검증** — 수정 전후 프로젝트 빌드 확인
- **AI 자동 수정** — 도구로 해결 못하는 이슈는 GLM (CodeGeeX-4)이 수정
- **안전한 기본값** — 수정 전 자동 백업. 빌드 실패시 자동 롤백
- **2단계 워크플로우** — 스캔 → 리뷰 → 수정. 예상치 못한 변경 없음
- **리포트 내보내기** — SARIF, HTML, Markdown, JSON, Text 형식 지원
- **크로스 플랫폼** — macOS와 Windows 모두 CLI 및 GUI 앱 지원

## 지원 언어 & 프레임워크

| 언어 | 도구 | 프레임워크 |
|------|------|-----------|
| Swift | SwiftLint, SwiftFormat | iOS, macOS 앱 |
| JavaScript/TypeScript | ESLint, Prettier | React, Next.js, Vue, Nuxt.js, Express, NestJS |
| Dart/Flutter | dart analyze, dart format | Flutter 앱 |
| Python | Ruff | Django, FastAPI, Flask 등 |

## 플랫폼 지원

| 기능 | macOS | Windows |
|------|-------|---------|
| CLI | ✅ | ✅ |
| GUI 앱 (SwiftUI) | ✅ | ❌ |
| GUI 앱 (Tauri) | ✅ | ✅ |
| Swift 스캔 | ✅ | ❌ |
| JS/TS 스캔 | ✅ | ✅ |
| Dart/Flutter 스캔 | ✅ | ✅ |
| Python 스캔 | ✅ | ✅ |
| AI 자동 수정 (GLM) | ✅ | ✅ |

> **참고**: Swift 도구는 Windows에서 사용할 수 없어 Swift 관련 스캐너는 자동으로 비활성화됩니다.

## 요구사항

### macOS
- macOS 14.0+
- Swift 5.9+
- Xcode 15+ (또는 Swift 툴체인)

### Windows
- Windows 10+
- Node.js (ESLint/Prettier용)
- Flutter SDK (Dart/Flutter 프로젝트용)
- Python + Ruff (Python 프로젝트용)

### 선택 도구 (자동 감지)

| 도구 | 용도 | macOS 설치 | Windows 설치 |
|------|------|------------|--------------|
| SwiftLint | Swift 린팅 | `brew install swiftlint` | 해당 없음 (macOS 전용) |
| SwiftFormat | Swift 포맷팅 | `brew install swiftformat` | 해당 없음 (macOS 전용) |
| Node.js + npx | JS/TS 린팅 & 포맷팅 | `brew install node` | [nodejs.org](https://nodejs.org) |
| Flutter SDK | Dart/Flutter 분석 | [flutter.dev](https://flutter.dev) | [flutter.dev](https://flutter.dev) |
| Ruff | Python 린팅 & 포맷팅 | `brew install ruff` | `pip install ruff` |

OhMyBug는 설치된 도구에 대해서만 스캐너를 실행합니다. 도구 미설치 = 스캐너 건너뜀.

## 설치

### CLI (macOS)

```bash
git clone https://github.com/insightflo/ohmybug.git
cd ohmybug/OhMyBugCore
swift build -c release

# 바이너리 위치:
# .build/release/ohmybug

# 선택: PATH에 복사
cp .build/release/ohmybug /usr/local/bin/
```

### CLI (Windows)

```powershell
git clone https://github.com/insightflo/ohmybug.git
cd ohmybug\OhMyBugCore
swift build -c release

# 바이너리 위치:
# .build\release\ohmybug.exe
```

### macOS 앱 (SwiftUI)

```bash
cd ohmybug/OhMyBugApp
./build-app.sh

# 앱 번들 생성 위치:
# .build/release/OhMyBug.app
```

또는 Xcode에서 `OhMyBugApp/Package.swift`를 열고 실행.

### Windows/크로스 플랫폼 앱 (Tauri)

```bash
cd ohmybug/OhMyBugWindows
npm install
npm run tauri dev      # 개발 모드
npm run tauri build    # 프로덕션 빌드
```

필요: [Rust](https://rustup.rs/), [Node.js](https://nodejs.org/)

## 사용법

### CLI

```bash
# 스캔만 (기본)
ohmybug check /path/to/project --verbose

# 스캔 + 자동 수정 (백업 생성, 빌드 실패시 롤백)
ohmybug check /path/to/project --fix

# 스캔 + AI 수정 (GLM CodeGeeX-4)
ohmybug check /path/to/project --fix --glm-key YOUR_API_KEY

# 리포트 내보내기
ohmybug check /path/to/project --format markdown --output report.md
ohmybug check /path/to/project --format sarif --output report.sarif
ohmybug check /path/to/project --format html --output report.html
```

### GUI 앱

1. 앱 실행
2. 프로젝트 폴더를 드래그 앤 드롭 (또는 클릭해서 열기)
3. **Scan Project** 클릭 — 리포트 확인
4. **Apply Fixes** 클릭 — 자동으로 백업 생성
5. 문제 발생시 → **Rollback** 클릭

**설정:**
- **Auto-apply fixes** — 스캔 후 자동으로 이슈 수정
- **Run build check** — 수정 후 프로젝트 빌드 검증

### GLM API 키

OhMyBug는 AI 자동 수정에 [Zhipu AI의 CodeGeeX-4](https://open.bigmodel.cn/)를 사용합니다:
- **CLI**: `--glm-key` 플래그로 전달 (저장 안함)
- **앱**: 설정 패널에서 입력 (로컬 저장, 기기 외부로 전송 안함)

## 아키텍처

```
ohmybug/
├── OhMyBugCore/             # SPM 라이브러리 + CLI (크로스 플랫폼)
│   ├── Sources/
│   │   ├── OhMyBugCore/
│   │   │   ├── Models/      # Issue, ScanResult, FixResult, PipelineReport
│   │   │   ├── Scanners/    # SwiftLint, SwiftFormat, ESLint, Prettier, Dart, Flutter, Ruff, BuildChecker
│   │   │   ├── Fixers/      # LLMClient (GLM), AIFixer
│   │   │   ├── Pipeline/    # PipelineEngine (actor), 스캐너 등록
│   │   │   └── Utils/       # ShellRunner, ToolInstaller, ProjectDetector, BackupManager, ReportFormatter
│   │   └── OhMyBugCLI/      # CLI 진입점
│   └── Tests/
├── OhMyBugApp/              # SwiftUI macOS 앱
│   └── OhMyBugApp/
│       ├── Views/           # ProjectDropZone, PhaseIndicator, LogView, ResultsDashboard, ScanReportView, SettingsPanel
│       ├── ViewModels/      # AppViewModel, AppSettings
│       └── Theme.swift      # 다크 테마
└── OhMyBugWindows/          # Tauri 앱 (Rust + React) Windows/크로스 플랫폼용
    ├── src/                 # React 프론트엔드
    ├── src-tauri/           # Rust 백엔드
    └── package.json
```

### 작동 방식

1. **감지** — `ProjectDetector`가 프로젝트 타입 식별 (Swift / JS / Flutter / Python / 혼합)
2. **등록** — `PipelineEngine`이 감지된 타입에 맞는 스캐너 등록
3. **스캔** — 각 스캐너가 도구를 실행하고 `ScanResult`와 이슈 반환
4. **리포트** — 이슈를 `ScanReport`로 집계 (심각도, 스캐너, 규칙, 파일별)
5. **수정** — 도구 기반 자동 수정 먼저, 이후 남은 이슈는 AI 수정
6. **검증** — 수정 후 재스캔 + 빌드 체크
7. **롤백** — 빌드 실패시 `BackupManager`가 모든 파일 복원

### 주요 설계 결정

- `PipelineEngine`은 안전한 동시성을 위해 Swift `actor` 사용
- 뷰는 `@Observable` 사용 (Swift 5.9 Observation 프레임워크)
- BuildChecker는 하위 디렉토리에서 빌드 가능한 타겟 검색
- 모든 쉘 명령은 `ShellRunner`를 통해 OS별 쉘 감지로 실행
- 플랫폼별 코드는 `#if os(Windows)` / `#if os(macOS)` 조건부 컴파일 사용
- Tauri 앱으로 네이티브 성능의 크로스 플랫폼 GUI 제공

## 라이선스

MIT
