// Adding Persistence and Security
use serde::Serialize;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Serialize)]
pub struct TelemetryEvent {
    pub event_id: String,
    pub timestamp: u64,
    pub action: String,
    pub status: String,
    pub device_tag: String, 
}

impl TelemetryEvent {
    pub fn new(action: &str, status: &str, device_tag: &str) -> Self {
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        
        Self {
            event_id: uuid::Uuid::new_v4().to_string(),
            timestamp,
            action: action.to_string(),
            status: status.to_string(),
            device_tag: device_tag.to_string(),
        }
    }

    pub fn log(&self) {
        // Principal Engineer Strategy: In dev, we log to stdout. Admin module reads this stream.
        println!("SATYA_TELEMETRY: {}", serde_json::to_string(self).unwrap_or_default());
    }
}