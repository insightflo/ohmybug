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

type AppState = "idle" | "scanning" | "scanned" | "fixing" | "fixed";

function App() {
  const [projectPath, setProjectPath] = useState<string | null>(null);
  const [appState, setAppState] = useState<AppState>("idle");
  const [summary, setSummary] = useState<ScanSummary | null>(null);
  const [logs, setLogs] = useState<string[]>([]);
  const [cliAvailable, setCliAvailable] = useState(true);

  useEffect(() => {
    invoke<boolean>("check_cli_available").then(setCliAvailable);
  }, []);

  const addLog = useCallback((msg: string, type: string = "info") => {
    const prefix = type === "success" ? "✅" : type === "error" ? "❌" : type === "warning" ? "⚠️" : "→";
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
      const result = await invoke<ScanResult>("scan_project", { path: projectPath });
      if (result.summary) {
        setSummary(result.summary);
        addLog(`Scan complete: ${result.summary.total} issues found`, "success");
      } else {
        addLog("Scan completed", "success");
      }
      setAppState("scanned");
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
          className={`drop-zone ${projectPath ? "has-project" : ""}`}
          onClick={handleOpenFolder}
          onDragOver={(e) => e.preventDefault()}
          onDrop={handleDrop}
        >
          <div className="drop-zone-icon">{projectPath ? "📁" : "📂"}</div>
          <div className="drop-zone-text">
            {projectPath ? projectName : "Drop Project or Click to Open"}
          </div>
          {projectPath && <div className="project-path">{projectPath}</div>}
        </div>

        {!cliAvailable && (
          <div style={{ color: "var(--error)", fontSize: 11, marginBottom: 16, textAlign: "center" }}>
            ⚠️ ohmybug CLI not found.<br />
            Please install it first.
          </div>
        )}

        <div className="actions">
          {appState === "idle" && (
            <button
              className="btn btn-primary"
              onClick={handleScan}
              disabled={!projectPath || !cliAvailable}
            >
              🔍 Scan Project
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
                🔧 Apply Fixes
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
                🔍 Scan Again
              </button>
              <button className="btn btn-secondary" onClick={handleDismiss}>
                Dismiss
              </button>
            </>
          )}
        </div>
      </div>

      <div className="main">
        <div className="header">
          <div className="header-title">
            {appState === "idle" && "Ready to Scan"}
            {appState === "scanning" && "Scanning..."}
            {appState === "scanned" && "Scan Report"}
            {appState === "fixing" && "Applying Fixes..."}
            {appState === "fixed" && "Fix Complete"}
          </div>
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
                    log.startsWith("✅") ? "success" :
                    log.startsWith("❌") ? "error" :
                    log.startsWith("⚠️") ? "warning" : "info"
                  }`}
                >
                  {log}
                </div>
              ))}
            </div>
          ) : (
            <div className="empty-state">
              <div className="empty-state-icon">🐞</div>
              <div>Select a project folder to scan for issues</div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default App;
