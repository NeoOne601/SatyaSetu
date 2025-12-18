use crate::service::TransactionService;
use crate::domain::{InteractionType}; 
use crate::parser::QrParser;

pub fn rust_init_core() -> String {
    match TransactionService::init_core() {
        Ok(_) => "Database Initialized".to_string(),
        Err(_) => "DB Init Failed".to_string(),
    }
}

pub fn rust_generate_did_safe() -> String {
    match TransactionService::create_identity() {
        Ok((identity, _kp)) => {
            serde_json::to_string(&identity).unwrap_or_default()
        },
        Err(_) => r#"{"error": "Gen Failed"}"#.to_string()
    }
}

pub fn rust_scan_qr(raw_qr_string: String) -> String {
    if let Some((vpa, name)) = QrParser::parse_upi_string(&raw_qr_string) {
        let interaction = QrParser::determine_interaction_type(&name);
        
        // Mock Keypair for demo
        let (_, temp_key) = TransactionService::create_identity().unwrap();

        let result = TransactionService::create_signed_transaction(
            &temp_key,
            interaction,
            Some(0),
            "INR".to_string(),
            format!("Interaction with {}", name),
            "8f7a...".to_string(),
            vpa
        );

        match result {
            Ok(signed) => serde_json::to_string(&signed).unwrap(),
            Err(e) => format!(r#"{{"error": "{:?}"}}"#, e),
        }
    } else {
        r#"{"error": "Invalid UPI QR"}"#.to_string()
    }
}
