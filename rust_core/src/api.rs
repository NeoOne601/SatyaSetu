/**
 * PROJECT SATYA: RUST CORE ENGINE
 * ===============================
 * PHASE: 5.9.9 (Final Trinity Baseline)
 * VERSION: 1.5.8
 * STATUS: STABLE (Nostr Ready)
 * DESCRIPTION:
 * Final Phase 5 API hub. Includes placeholder for Nostr publishing 
 * to ensure Flutter compilation parity.
 */

use crate::persistence::{VaultManager, SatyaVault};
use crate::crypto::{VaultKey, generate_signing_key, sign_with_key};
use crate::domain::{SatyaIdentity, SignedIntent, IntentPayload, InteractionType, PROTOCOL_VERSION};
use crate::parser::parse_upi_url;
use anyhow::{Result, anyhow};
use std::sync::Mutex;
use once_cell::sync::Lazy;

pub use crate::domain::UpiIntent;

static VAULT_STATE: Lazy<Mutex<Option<(VaultManager, SatyaVault, String, String)>>> = 
    Lazy::new(|| Mutex::new(None));

pub fn rust_init_core() -> String {
    "Satya Core Phase 5.9.9 Active".to_string()
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
        Err(e) => Err(anyhow!("Unlock failed: {}", e))
    }
}

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
        let priv_key = vault.private_keys.get(&identity_id).ok_or_else(|| anyhow!("Key material missing"))?;
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

pub fn rust_publish_to_nostr(_signed_json: String) -> Result<bool> {
    Ok(false) // Placeholder for Phase 6
}

pub fn rust_get_identities() -> Result<Vec<SatyaIdentity>> {
    let state = VAULT_STATE.lock().unwrap();
    if let Some((_, vault, _, _)) = &*state { Ok(vault.identities.clone()) }
    else { Err(anyhow!("Vault Locked")) }
}

pub fn rust_scan_qr(raw_qr_string: String) -> Result<String> {
    match parse_upi_url(&raw_qr_string) {
        Ok(intent) => Ok(serde_json::to_string(&intent).unwrap()),
        Err(e) => Err(anyhow!("Parsing error: {}", e))
    }
}