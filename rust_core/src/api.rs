/**
 * PROJECT SATYA: RUST CORE ENGINE
 * ===============================
 * PHASE: 6.8 (Forensic Synchronization)
 * VERSION: 1.6.8
 * STATUS: STABLE (Native Reset Implemented)
 */

use crate::persistence::{VaultManager, SatyaVault};
use crate::crypto::{VaultKey, generate_signing_key, sign_with_key};
use crate::domain::{SatyaIdentity, SignedIntent, IntentPayload, InteractionType, PROTOCOL_VERSION};
use crate::parser::parse_upi_url;
use anyhow::{Result, anyhow};
use std::sync::Mutex;
use once_cell::sync::Lazy;
use nostr_sdk::prelude::*;
use std::time::Duration;
use std::fs;

pub use crate::domain::UpiIntent;

static VAULT_STATE: Lazy<Mutex<Option<(VaultManager, SatyaVault, String, String)>>> = 
    Lazy::new(|| Mutex::new(None));

pub fn rust_init_core() -> String {
    "Satya Core Phase 6.8 (Forensic) Active".to_string()
}

/// NEW: Explicit Native Reset to handle macOS Sandbox File Locks
pub fn rust_reset_vault(storage_path: String) -> Result<bool> {
    println!("SATYA_RUST: Executing Native Forensic Wipe...");
    
    // 1. Purge In-Memory State
    let mut state = VAULT_STATE.lock().unwrap();
    *state = None;

    // 2. Synchronous Disk Wipe
    let mut path = std::path::PathBuf::from(storage_path);
    path.push("satya_vault");
    if path.exists() {
        fs::remove_dir_all(&path)?;
        println!("SATYA_RUST: Filesystem sync complete. Vault purged.");
    }
    Ok(true)
}

pub fn rust_initialize_vault(pin: String, hw_id: String, storage_path: String) -> Result<bool> {
    println!("SATYA_RUST: Attempting Unlock at path: {}", storage_path);
    let manager = VaultManager::new(&storage_path);
    let key = VaultKey::from_pin(&pin, b"satya_salt_v1")?;
    
    match manager.load(&key, hw_id.as_bytes()) {
        Ok(vault) => {
            let mut state = VAULT_STATE.lock().unwrap();
            *state = Some((manager, vault, pin, hw_id));
            println!("SATYA_RUST: Vault logic initialized successfully.");
            Ok(true)
        },
        Err(e) => {
            println!("SATYA_RUST: Load Error: {}", e);
            Err(anyhow!("{}", e))
        }
    }
}

// ... Create Identity & Sign Intent preserved from Phase 6.7 ...
pub fn rust_create_identity(label: String) -> Result<SatyaIdentity> {
    let mut state = VAULT_STATE.lock().unwrap();
    if let Some((manager, vault, pin, hw_id)) = &mut *state {
        let id_uuid = uuid::Uuid::new_v4().to_string();
        let priv_key = generate_signing_key();
        let new_id = SatyaIdentity { id: id_uuid.clone(), label, did: format!("did:satya:{}", id_uuid) };
        vault.identities.push(new_id.clone());
        vault.private_keys.insert(id_uuid, priv_key);
        let key = VaultKey::from_pin(pin, b"satya_salt_v1")?;
        manager.atomic_save(&key, hw_id.as_bytes(), vault)?;
        Ok(new_id)
    } else { Err(anyhow!("Vault Locked")) }
}

pub fn rust_sign_intent(identity_id: String, upi_url: String) -> Result<String> {
    let state = VAULT_STATE.lock().unwrap();
    if let Some((_, vault, _, _)) = &*state {
        let priv_key = vault.private_keys.get(&identity_id).ok_or_else(|| anyhow!("Keys missing"))?;
        let intent = parse_upi_url(&upi_url)?;
        let payload = IntentPayload {
            version: PROTOCOL_VERSION.to_string(),
            timestamp: chrono::Utc::now().timestamp(),
            interaction: InteractionType::Payment,
            amount_cents: intent.amount.parse::<f64>().ok().map(|a| (a * 100.0) as u64),
            currency: intent.currency,
            metadata: format!("To: {}", intent.name),
            geo_hash: "00000".to_string(),
            counterparty_did: format!("vpa:{}", intent.vpa),
        };
        let payload_json = serde_json::to_string(&payload)?;
        let signature_hex = sign_with_key(priv_key, payload_json.as_bytes())?;
        let signed = SignedIntent { payload, signature_hex, signer_did: format!("did:satya:{}", identity_id) };
        Ok(serde_json::to_string(&signed)?)
    } else { Err(anyhow!("Vault Locked")) }
}

pub fn rust_publish_to_nostr(signed_json: String) -> Result<bool> {
    let rt = tokio::runtime::Builder::new_multi_thread().enable_all().worker_threads(2).build()?;
    rt.block_on(async {
        let keys = Keys::generate();
        let client = Client::new(keys.clone());
        client.add_relay("wss://relay.damus.io").await?;
        client.add_relay("wss://nos.lol").await?;
        let connect_future = client.connect();
        if let Err(_) = tokio::time::timeout(Duration::from_secs(15), connect_future).await {
            return Err(anyhow!("Relay connection timeout"));
        }
        let event = EventBuilder::new(Kind::from(29001), signed_json, []).sign(&keys).await?;
        client.send_event(event).await?;
        client.disconnect().await?;
        Ok(true)
    })
}

pub fn rust_get_identities() -> Result<Vec<SatyaIdentity>> {
    let state = VAULT_STATE.lock().unwrap();
    if let Some((_, vault, _, _)) = &*state { Ok(vault.identities.clone()) }
    else { Err(anyhow!("Vault Locked")) }
}

pub fn rust_scan_qr(raw_qr_string: String) -> Result<String> {
    match parse_upi_url(&raw_qr_string) {
        Ok(intent) => Ok(serde_json::to_string(&intent).unwrap()),
        Err(e) => Err(anyhow!("QR error: {}", e))
    }
}