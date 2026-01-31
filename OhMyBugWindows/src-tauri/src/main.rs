#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use std::process::Command;
use tauri::Manager;

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

#[tauri::command]
async fn scan_project(path: String) -> Result<ScanResult, String> {
    let output = Command::new("ohmybug")
        .args(["check", &path, "--format", "json"])
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
async fn scan_project_markdown(path: String) -> Result<String, String> {
    let output = Command::new("ohmybug")
        .args(["check", &path, "--format", "markdown"])
        .output()
        .map_err(|e| format!("Failed to execute ohmybug: {}", e))?;

    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();

    Ok(if stdout.is_empty() { stderr } else { stdout })
}

#[tauri::command]
async fn fix_project(path: String) -> Result<ScanResult, String> {
    let output = Command::new("ohmybug")
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
    Command::new("ohmybug")
        .arg("--version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
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
            scan_project_markdown,
            fix_project,
            check_cli_available,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
