import { useState, useEffect, useCallback } from "react";
import { invoke } from "@tauri-apps/api/tauri";
import { open } from "@tauri-apps/api/dialog";

interface ScanSummary {
  total: number;
  critical: number;
  high: number;
  medium: number;
  low: number;
}

interface ScanResult {
  success: boolean;
  output: string;
  summary?: ScanSummary;
}

interface Settings {
  autoApplyFixes: boolean;
  runBuildCheck: boolean;
}

type AppState = "idle" | "scanning" | "scanned" | "fixing" | "fixed";

const FolderIcon = ({ filled = false, size = 28 }: { filled?: boolean; size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    {filled ? (
      <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" fill="currentColor" />
    ) : (
      <>
        <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" />
        <line x1="12" y1="11" x2="12" y2="17" />
        <line x1="9" y1="14" x2="15" y2="14" />
      </>
    )}
  </svg>
);

const MagnifyingGlassIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="11" cy="11" r="8" />
    <line x1="21" y1="21" x2="16.65" y2="16.65" />
  </svg>
);

const WrenchIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" />
  </svg>
);

const LogIcon = ({ size = 48 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" opacity="0.4">
    <line x1="4" y1="9" x2="20" y2="9" />
    <line x1="4" y1="15" x2="20" y2="15" />
    <line x1="10" y1="3" x2="8" y2="21" />
    <line x1="16" y1="3" x2="14" y2="21" />
  </svg>
);

const Toggle = ({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) => (
  <button
    className={`toggle ${checked ? "on" : ""}`}
    onClick={() => onChange(!checked)}
    type="button"
  >
    <span className="toggle-thumb" />
  </button>
);

function App() {
  const [projectPath, setProjectPath] = useState<string | null>(null);
  const [appState, setAppState] = useState<AppState>("idle");
  const [summary, setSummary] = useState<ScanSummary | null>(null);
  const [logs, setLogs] = useState<string[]>([]);
  const [cliAvailable, setCliAvailable] = useState(true);
  const [isHovering, setIsHovering] = useState(false);
  const [settings, setSettings] = useState<Settings>({
    autoApplyFixes: true,
    runBuildCheck: true,
  });

  useEffect(() => {
    invoke<boolean>("check_cli_available").then(setCliAvailable);
  }, []);

  const addLog = useCallback((msg: string, type: string = "info") => {
    const prefix = type === "success" ? "✓" : type === "error" ? "✗" : type === "warning" ? "!" : "→";
    setLogs((prev) => [...prev, `${prefix} ${msg}`]);
  }, []);

  const handleOpenFolder = async () => {
    const selected = await open({
      directory: true,
      multiple: false,
      title: "Select Project Folder",
    });
    if (selected && typeof selected === "string") {
      setProjectPath(selected);
      setSummary(null);
      setLogs([]);
      setAppState("idle");
    }
  };

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsHovering(false);
    const files = e.dataTransfer.files;
    if (files.length > 0) {
      const path = (files[0] as any).path;
      if (path) {
        setProjectPath(path);
        setSummary(null);
        setLogs([]);
        setAppState("idle");
      }
    }
  }, []);

  const handleScan = async () => {
    if (!projectPath) return;
    
    setAppState("scanning");
    setLogs([]);
    addLog("Starting scan...");

    try {
      const result = await invoke<ScanResult>("scan_project", { 
        path: projectPath,
        autoFix: settings.autoApplyFixes 
      });
      if (result.summary) {
        setSummary(result.summary);
        addLog(`Scan complete: ${result.summary.total} issues found`, "success");
      } else {
        addLog("Scan completed", "success");
      }
      setAppState(settings.autoApplyFixes ? "fixed" : "scanned");
    } catch (error) {
      addLog(`Scan failed: ${error}`, "error");
      setAppState("idle");
    }
  };

  const handleFix = async () => {
    if (!projectPath) return;
    
    setAppState("fixing");
    addLog("Applying fixes...");

    try {
      const result = await invoke<ScanResult>("fix_project", { path: projectPath });
      if (result.summary) {
        setSummary(result.summary);
        addLog(`Fix complete: ${result.summary.total} remaining issues`, "success");
      } else {
        addLog("Fix completed", "success");
      }
      setAppState("fixed");
    } catch (error) {
      addLog(`Fix failed: ${error}`, "error");
      setAppState("scanned");
    }
  };

  const handleDismiss = () => {
    setSummary(null);
    setLogs([]);
    setAppState("idle");
  };

  const projectName = projectPath?.split(/[/\\]/).pop() || "";

  return (
    <div className="app">
      <div className="sidebar">
        <div className="logo">OhMyBug</div>

        <div
          className={`drop-zone ${projectPath ? "has-project" : ""} ${isHovering ? "active" : ""}`}
          onClick={handleOpenFolder}
          onDragOver={(e) => { e.preventDefault(); setIsHovering(true); }}
          onDragLeave={() => setIsHovering(false)}
          onDrop={handleDrop}
        >
          <div className="drop-zone-icon" style={{ color: projectPath ? "var(--accent)" : (isHovering ? "var(--accent)" : "var(--text-secondary)") }}>
            <FolderIcon filled={!!projectPath} />
          </div>
          <div className="drop-zone-text" style={{ color: isHovering ? "var(--accent)" : undefined }}>
            {projectPath ? projectName : "Drop Project or Click to Open"}
          </div>
          {projectPath && <div className="project-path">{projectPath}</div>}
        </div>

        <div className="actions">
          {appState === "idle" && (
            <button
              className="btn btn-primary"
              onClick={handleScan}
              disabled={!projectPath || !cliAvailable}
            >
              <MagnifyingGlassIcon /> Scan Project
            </button>
          )}

          {appState === "scanning" && (
            <button className="btn btn-primary" disabled>
              <span className="spinner"></span> Scanning...
            </button>
          )}

          {appState === "scanned" && (
            <>
              <button className="btn btn-warning" onClick={handleFix}>
                <WrenchIcon /> Apply Fixes
              </button>
              <button className="btn btn-secondary" onClick={handleDismiss}>
                Dismiss
              </button>
            </>
          )}

          {appState === "fixing" && (
            <button className="btn btn-warning" disabled>
              <span className="spinner"></span> Fixing...
            </button>
          )}

          {appState === "fixed" && (
            <>
              <button className="btn btn-primary" onClick={handleScan}>
                <MagnifyingGlassIcon /> Scan Again
              </button>
              <button className="btn btn-secondary" onClick={handleDismiss}>
                Dismiss
              </button>
            </>
          )}
        </div>

        <div className="divider" />

        <div className="settings">
          <div className="settings-title">Settings</div>
          
          <div className="settings-row">
            <span>Auto-apply fixes</span>
            <Toggle 
              checked={settings.autoApplyFixes} 
              onChange={(v) => setSettings(s => ({ ...s, autoApplyFixes: v }))} 
            />
          </div>
          
          <div className="settings-row">
            <span>Run build check</span>
            <Toggle 
              checked={settings.runBuildCheck} 
              onChange={(v) => setSettings(s => ({ ...s, runBuildCheck: v }))} 
            />
          </div>
        </div>

        {!cliAvailable && (
          <div className="cli-warning">
            ⚠ ohmybug CLI not found.<br />
            Please install it first.
          </div>
        )}
      </div>

      <div className="main">
        <div className="header">
          <div className="header-title">Execution Log</div>
          <div className="header-count">{logs.length} entries</div>
        </div>

        <div className="content">
          {summary && (
            <div className="summary">
              <div className="summary-card total">
                <div className="summary-value">{summary.total}</div>
                <div className="summary-label">Total</div>
              </div>
              <div className="summary-card critical">
                <div className="summary-value">{summary.critical}</div>
                <div className="summary-label">Critical</div>
              </div>
              <div className="summary-card high">
                <div className="summary-value">{summary.high}</div>
                <div className="summary-label">High</div>
              </div>
              <div className="summary-card medium">
                <div className="summary-value">{summary.medium}</div>
                <div className="summary-label">Medium</div>
              </div>
              <div className="summary-card low">
                <div className="summary-value">{summary.low}</div>
                <div className="summary-label">Low</div>
              </div>
            </div>
          )}

          {logs.length > 0 ? (
            <div className="log">
              {logs.map((log, i) => (
                <div
                  key={i}
                  className={`log-entry ${
                    log.startsWith("✓") ? "success" :
                    log.startsWith("✗") ? "error" :
                    log.startsWith("!") ? "warning" : "info"
                  }`}
                >
                  {log}
                </div>
              ))}
            </div>
          ) : (
            <div className="empty-state">
              <div className="empty-state-icon">
                <LogIcon />
              </div>
              <div className="empty-state-title">No logs yet</div>
              <div className="empty-state-desc">Load a project and run Auto Mode to see output</div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default App;
