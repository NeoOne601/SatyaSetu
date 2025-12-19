use crate::persistence::{VaultManager, SatyaVault};
use crate::crypto::{VaultKey, decrypt_with_binding};
use crate::telemetry::TelemetryEvent;
use crate::domain::SatyaIdentity;
use anyhow::{Result, anyhow};
use std::sync::Mutex;
use once_cell::sync::Lazy;

// PRINCIPAL DESIGN: Global State for the active session
// This keeps the vault in memory while the app is active (SoC)
static VAULT_STATE: Lazy<Mutex<Option<(VaultManager, SatyaVault, String, String)>>> = 
    Lazy::new(|| Mutex::new(None));

/// Initializes or Unlocks the Secure Vault
/// - pin: User 6-digit PIN
/// - hw_id: Hardware Identifier (for Silicon Binding)
/// - storage_path: Application Sandbox path from Flutter
pub fn rust_initialize_vault(
    pin: String, 
    hw_id: String, 
    storage_path: String
) -> Result<bool> {
    let manager = VaultManager::new(&storage_path);
    let key = VaultKey::from_pin(&pin, b"satya_salt_v1")?;
    
    // Load existing or create new
    match manager.load(&key, hw_id.as_bytes()) {
        Ok(vault) => {
            // Instrumentation: Log success for the Admin (God Mode)
            TelemetryEvent::new("vault_unlock", "success", &hw_id).log();
            
            let mut state = VAULT_STATE.lock().unwrap();
            *state = Some((manager, vault, pin, hw_id));
            Ok(true)
        },
        Err(e) => {
            // Instrumentation: Detect potential brute-force or unauthorized device
            TelemetryEvent::new("vault_unlock", "failure", &hw_id).log();
            Err(anyhow!("Unlock failed: {}", e))
        }
    }
}

/// Retrieves identities from the decrypted memory-space
pub fn rust_get_identities() -> Result<Vec<SatyaIdentity>> {
    let state = VAULT_STATE.lock().unwrap();
    if let Some((_, vault, _, _)) = &*state {
        Ok(vault.identities.clone())
    } else {
        Err(anyhow!("Vault is locked"))
    }
}

/// Creates and saves a new identity atomically
pub fn rust_add_identity(label: String) -> Result<SatyaIdentity> {
    let mut state = VAULT_STATE.lock().unwrap();
    if let Some((manager, vault, pin, hw_id)) = &mut *state {
        let new_id = SatyaIdentity {
            id: uuid::Uuid::new_v4().to_string(),
            label,
            did: "did:satya:pending".to_string(), // Will be generated in crypto.rs
        };
        
        vault.identities.push(new_id.clone());
        
        // Atomic Save
        let key = VaultKey::from_pin(pin, b"satya_salt_v1")?;
        manager.atomic_save(&key, hw_id.as_bytes(), vault)?;
        
        TelemetryEvent::new("identity_created", "success", hw_id).log();
        Ok(new_id)
    } else {
        Err(anyhow!("Vault is locked"))
    }
}