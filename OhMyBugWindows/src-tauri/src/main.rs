#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use std::process::Command;
use std::path::PathBuf;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ScanResult {
    pub success: bool,
    pub output: String,
    pub summary: Option<ScanSummary>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ScanSummary {
    pub total: i32,
    pub critical: i32,
    pub high: i32,
    pub medium: i32,
    pub low: i32,
}

fn find_cli() -> Option<PathBuf> {
    let candidates = [
        dirs::home_dir().map(|h| h.join("bin/ohmybug")),
        Some(PathBuf::from("/usr/local/bin/ohmybug")),
        Some(PathBuf::from("/opt/homebrew/bin/ohmybug")),
        Some(PathBuf::from("ohmybug")),
    ];

    for candidate in candidates.iter().flatten() {
        if candidate.exists() || candidate.to_str() == Some("ohmybug") {
            if let Ok(output) = Command::new(candidate).arg("--version").output() {
                if output.status.success() {
                    return Some(candidate.clone());
                }
            }
        }
    }
    None
}

fn get_cli_path() -> Result<PathBuf, String> {
    find_cli().ok_or_else(|| "ohmybug CLI not found".to_string())
}

#[tauri::command]
async fn scan_project(path: String, auto_fix: bool) -> Result<ScanResult, String> {
    let cli = get_cli_path()?;
    let mut args = vec!["check", &path, "--format", "json"];
    if auto_fix {
        args.push("--fix");
    }

    let output = Command::new(&cli)
        .args(&args)
        .output()
        .map_err(|e| format!("Failed to execute ohmybug: {}", e))?;

    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();

    if !output.status.success() && stdout.is_empty() {
        return Err(format!("Scan failed: {}", stderr));
    }

    let summary = parse_summary(&stdout);

    Ok(ScanResult {
        success: output.status.success(),
        output: if stdout.is_empty() { stderr } else { stdout },
        summary,
    })
}

#[tauri::command]
async fn fix_project(path: String) -> Result<ScanResult, String> {
    let cli = get_cli_path()?;
    let output = Command::new(&cli)
        .args(["check", &path, "--fix", "--format", "json"])
        .output()
        .map_err(|e| format!("Failed to execute ohmybug: {}", e))?;

    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();

    let summary = parse_summary(&stdout);

    Ok(ScanResult {
        success: output.status.success(),
        output: if stdout.is_empty() { stderr } else { stdout },
        summary,
    })
}

#[tauri::command]
async fn check_cli_available() -> bool {
    find_cli().is_some()
}

#[tauri::command]
async fn get_cli_version() -> Result<String, String> {
    let cli = get_cli_path()?;
    let output = Command::new(&cli)
        .arg("--version")
        .output()
        .map_err(|e| format!("Failed to get version: {}", e))?;

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn parse_summary(output: &str) -> Option<ScanSummary> {
    if let Ok(json) = serde_json::from_str::<serde_json::Value>(output) {
        if let Some(summary) = json.get("summary") {
            return Some(ScanSummary {
                total: summary.get("total").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
                critical: summary.get("critical").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
                high: summary.get("high").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
                medium: summary.get("medium").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
                low: summary.get("low").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
            });
        }
    }
    None
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            scan_project,
            fix_project,
            check_cli_available,
            get_cli_version,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
