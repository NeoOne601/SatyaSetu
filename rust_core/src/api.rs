// Adding Persistence and Security
use crate::persistence::{VaultManager, SatyaVault};
use crate::crypto::VaultKey;
use crate::domain::SatyaIdentity;
use crate::parser::parse_upi_url;
use anyhow::{Result, anyhow};
use std::sync::Mutex;
use once_cell::sync::Lazy;

// PRINCIPAL FIX: Re-exporting for the bridge generator
pub use crate::domain::UpiIntent;

static VAULT_STATE: Lazy<Mutex<Option<(VaultManager, SatyaVault, String, String)>>> = 
    Lazy::new(|| Mutex::new(None));

// SHIM: satisfying bridge_generated.rs legacy calls
pub fn rust_init_core() -> String {
    "Satya Core Phase 3 Ready".to_string()
}

pub fn rust_initialize_vault(pin: String, hw_id: String, storage_path: String) -> Result<bool> {
    let manager = VaultManager::new(&storage_path);
    let key = VaultKey::from_pin(&pin, b"satya_salt_v1")?;
    
    match manager.load(&key, hw_id.as_bytes()) {
        Ok(vault) => {
            let mut state = VAULT_STATE.lock().unwrap();
            *state = Some((manager, vault, pin, hw_id));
            Ok(true)
        },
        Err(e) => Err(anyhow!("Vault Unlock Failed: {}", e))
    }
}

// SHIM: satisfying bridge_generated.rs legacy calls
pub fn rust_generate_did_safe() -> Result<String> {
    rust_create_identity("Primary".to_string()).map(|id| id.did)
}

pub fn rust_create_identity(label: String) -> Result<SatyaIdentity> {
    let mut state = VAULT_STATE.lock().unwrap();
    if let Some((manager, vault, pin, hw_id)) = &mut *state {
        let new_id = SatyaIdentity {
            id: uuid::Uuid::new_v4().to_string(),
            label,
            did: format!("did:satya:{}", uuid::Uuid::new_v4()),
        };
        vault.identities.push(new_id.clone());
        let key = VaultKey::from_pin(pin, b"satya_salt_v1")?;
        manager.atomic_save(&key, hw_id.as_bytes(), vault)?;
        Ok(new_id)
    } else {
        Err(anyhow!("Vault Locked"))
    }
}

// SHIM: satisfying bridge_generated.rs legacy calls
pub fn rust_scan_qr(raw_qr_string: String) -> Result<String> {
    match parse_upi_url(&raw_qr_string) {
        Ok(intent) => Ok(serde_json::to_string(&intent).unwrap()),
        Err(e) => Err(anyhow!("Scan failed: {}", e))
    }
}

pub fn rust_get_identities() -> Result<Vec<SatyaIdentity>> {
    let state = VAULT_STATE.lock().unwrap();
    if let Some((_, vault, _, _)) = &*state {
        Ok(vault.identities.clone())
    } else {
        Err(anyhow!("Vault Locked"))
    }
}