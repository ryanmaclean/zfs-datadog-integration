// Tauri iOS app for ZFS development
#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

use tauri::Manager;
use std::fs;
use std::path::PathBuf;

// Save file to iCloud
#[tauri::command]
async fn save_to_icloud(filename: String, content: String) -> Result<String, String> {
    let home = std::env::var("HOME").map_err(|e| e.to_string())?;
    let icloud_path = format!(
        "{}/Library/Mobile Documents/iCloud~com~zfsdev/Documents",
        home
    );
    
    // Create directory if needed
    fs::create_dir_all(&icloud_path).map_err(|e| e.to_string())?;
    
    let file_path = format!("{}/{}", icloud_path, filename);
    fs::write(&file_path, content).map_err(|e| e.to_string())?;
    
    Ok(format!("Saved to iCloud: {}", file_path))
}

// Load file from iCloud
#[tauri::command]
async fn load_from_icloud(filename: String) -> Result<String, String> {
    let home = std::env::var("HOME").map_err(|e| e.to_string())?;
    let file_path = format!(
        "{}/Library/Mobile Documents/iCloud~com~zfsdev/Documents/{}",
        home, filename
    );
    
    fs::read_to_string(&file_path).map_err(|e| e.to_string())
}

// List files in iCloud
#[tauri::command]
async fn list_icloud_files() -> Result<Vec<String>, String> {
    let home = std::env::var("HOME").map_err(|e| e.to_string())?;
    let icloud_path = format!(
        "{}/Library/Mobile Documents/iCloud~com~zfsdev/Documents",
        home
    );
    
    let entries = fs::read_dir(&icloud_path).map_err(|e| e.to_string())?;
    let files: Vec<String> = entries
        .filter_map(|e| e.ok())
        .filter_map(|e| e.file_name().into_string().ok())
        .collect();
    
    Ok(files)
}

// Connect to Mac via HTTP (for code-server)
#[tauri::command]
async fn connect_to_mac(mac_ip: String, port: u16) -> Result<String, String> {
    let url = format!("http://{}:{}", mac_ip, port);
    
    // Test connection
    let client = reqwest::Client::new();
    client.get(&url)
        .send()
        .await
        .map_err(|e| format!("Connection failed: {}", e))?;
    
    Ok(url)
}

// SSH command via HTTP proxy (safer than direct SSH)
#[tauri::command]
async fn run_ssh_command(
    mac_ip: String,
    command: String
) -> Result<String, String> {
    // In production, you'd have a small HTTP server on Mac
    // that accepts commands and returns output
    let url = format!("http://{}:3000/exec", mac_ip);
    
    let client = reqwest::Client::new();
    let response = client.post(&url)
        .json(&serde_json::json!({
            "command": command
        }))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    
    response.text().await.map_err(|e| e.to_string())
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            save_to_icloud,
            load_from_icloud,
            list_icloud_files,
            connect_to_mac,
            run_ssh_command
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
