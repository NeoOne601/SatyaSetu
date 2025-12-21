/**
 * PROJECT SATYA: RUST CORE ENGINE
 * ===============================
 * PHASE: 4.0 (Identity Lifecycle & Persistence)
 * VERSION: 1.1.0
 * STATUS: STABLE
 * DESCRIPTION:
 * Entry point for FFI calls. Manages the global VAULT_STATE and 
 * coordinates with persistence and crypto modules.
 * CHANGE LOG:
 * - Phase 2.0: Initial QR scanner shim.
 * - Phase 3.3: Vault Initialization (Argon2id/XChaCha20) added.
 * - Phase 4.0: Identity Ledger persistence and retrieval finalized.
 */

use crate::persistence::{VaultManager, SatyaVault};
use crate::crypto::VaultKey;
use crate::domain::SatyaIdentity;
use crate::parser::parse_upi_url;
use anyhow::{Result, anyhow};
use std::sync::Mutex;
use once_cell::sync::Lazy;

pub use crate::domain::UpiIntent;

/// Global thread-safe session state holding the active vault manager and data
static VAULT_STATE: Lazy<Mutex<Option<(VaultManager, SatyaVault, String, String)>>> = 
    Lazy::new(|| Mutex::new(None));

pub fn rust_init_core() -> String {
    "Satya Core Phase 4 Baselined".to_string()
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
        Err(e) => Err(anyhow!("Vault decryption failure: {}", e))
    }
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
        
        // Re-derive key for the atomic save operation
        let key = VaultKey::from_pin(pin, b"satya_salt_v1")?;
        manager.atomic_save(&key, hw_id.as_bytes(), vault)?;
        
        Ok(new_id)
    } else {
        Err(anyhow!("Vault is locked"))
    }
}

pub fn rust_get_identities() -> Result<Vec<SatyaIdentity>> {
    let state = VAULT_STATE.lock().unwrap();
    if let Some((_, vault, _, _)) = &*state {
        Ok(vault.identities.clone())
    } else {
        Err(anyhow!("Vault is locked"))
    }
}

pub fn rust_scan_qr(raw_qr_string: String) -> Result<String> {
    match parse_upi_url(&raw_qr_string) {
        Ok(intent) => Ok(serde_json::to_string(&intent).unwrap()),
        Err(e) => Err(anyhow!("Parsing failure: {}", e))
    }
}