# OhMyBug Windows

Windows GUI application for OhMyBug built with Tauri (Rust + React).

## Prerequisites

1. **Node.js** (v18+)
2. **Rust** - Install from https://rustup.rs/
3. **OhMyBug CLI** - The CLI must be installed and available in PATH

## Development Setup

```bash
# Install dependencies
npm install

# Run in development mode
npm run tauri dev

# Build for production
npm run tauri build
```

## Project Structure

```
OhMyBugWindows/
├── src/                    # React frontend
│   ├── App.tsx            # Main application component
│   ├── main.tsx           # Entry point
│   └── styles.css         # Styling
├── src-tauri/             # Rust backend
│   ├── src/main.rs        # Tauri commands
│   ├── Cargo.toml         # Rust dependencies
│   └── tauri.conf.json    # Tauri configuration
├── index.html             # HTML entry
├── package.json           # Node dependencies
└── vite.config.ts         # Vite configuration
```

## Features

- **Drag & Drop** or **Click to Open** folder selection
- Real-time scan progress display
- Issue summary with severity breakdown
- Auto-fix functionality
- Dark theme UI matching macOS version

## Building for Windows

```bash
# On Windows with Rust installed
npm run tauri build

# Output will be in src-tauri/target/release/
```

## Notes

- This application wraps the OhMyBug CLI
- The CLI must be compiled for Windows separately
- Icons should be added to `src-tauri/icons/` before building
