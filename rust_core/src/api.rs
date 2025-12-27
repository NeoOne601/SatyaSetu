/**
 * FILE: rust_core/src/api.rs
 * VERSION: 1.7.14
 * PHASE: Phase 7 (Multi-Identity Derivation)
 * FIX: 
 * 1. Resolved 'new_from_slice' ambiguity by using Fully Qualified Syntax.
 * 2. Maintained 'to_event' for Nostr SDK 0.26.
 * 3. Ensured 'hex' and 'hmac' are strictly typed.
 */

use crate::persistence::{VaultManager, SatyaVault};
use crate::crypto::{VaultKey, sign_with_key};
use crate::domain::{SatyaIdentity, SignedIntent, IntentPayload, InteractionType, PROTOCOL_VERSION};
use crate::parser::parse_upi_url;
use anyhow::{Result, anyhow};
use std::sync::Mutex;
use once_cell::sync::Lazy;
// Nostr Imports
use nostr_sdk::prelude::{Keys, Client, EventBuilder, Kind, Tag}; 
use std::time::{SystemTime, UNIX_EPOCH};
use std::path::PathBuf;
use std::fs;
use uuid::Uuid;

// Cryptographic Imports
use hmac::Mac; // Essential for the Mac trait
use sha2::Sha512;

pub use crate::domain::UpiIntent;

static VAULT_STATE: Lazy<Mutex<Option<(VaultManager, SatyaVault, String, String)>>> = 
    Lazy::new(|| Mutex::new(None));

pub fn rust_initialize_vault(pin: String, hw_id: String, storage_path: String) -> Result<bool> {
    let manager = VaultManager::new(&storage_path);
    let key = VaultKey::from_pin(&pin, b"satya_salt_v1")?;
    
    match manager.load(&key, hw_id.as_bytes()) {
        Ok(mut vault) => {
            if vault.master_seed.is_empty() {
                vault.master_seed = (0..32).map(|_| rand::random::<u8>()).collect();
                manager.atomic_save(&key, hw_id.as_bytes(), &vault)?;
            }
            let mut state = VAULT_STATE.lock().unwrap();
            *state = Some((manager, vault, pin, hw_id));
            Ok(true)
        },
        Err(e) => Err(anyhow!("{}", e))
    }
}

pub fn rust_create_identity(label: String) -> Result<SatyaIdentity> {
    let mut state = VAULT_STATE.lock().unwrap();
    if let Some((manager, vault, pin, hw_id)) = &mut *state {
        let index = vault.identities.len();
        
        // FIXED: Fully Qualified Syntax to resolve 'new_from_slice' ambiguity.
        // We explicitly tell Rust to use the 'Mac' trait implementation.
        let mut mac = <hmac::SimpleHmac<Sha512> as hmac::Mac>::new_from_slice(&vault.master_seed)
            .map_err(|_| anyhow!("Derivation Error"))?;
        
        mac.update(format!("satya_identity_{}", index).as_bytes());
        let result = mac.finalize().into_bytes();
        let priv_key = result[..32].to_vec();

        let id_uuid = Uuid::new_v4().to_string();
        let new_id = SatyaIdentity { 
            id: id_uuid.clone(), 
            label, 
            did: format!("did:satya:{}", id_uuid) 
        };
        
        vault.identities.push(new_id.clone());
        vault.private_keys.insert(id_uuid, priv_key);
        
        let key = VaultKey::from_pin(pin, b"satya_salt_v1")?;
        manager.atomic_save(&key, hw_id.as_bytes(), vault)?;
        Ok(new_id)
    } else { Err(anyhow!("Vault Locked")) }
}

pub fn rust_get_identities() -> Result<Vec<SatyaIdentity>> {
    let state = VAULT_STATE.lock().unwrap();
    if let Some((_, vault, _, _)) = &*state { Ok(vault.identities.clone()) }
    else { Err(anyhow!("Vault Locked")) }
}

pub fn rust_scan_qr(raw_qr_string: String) -> Result<String> {
    let intent = parse_upi_url(&raw_qr_string)?;
    Ok(serde_json::to_string(&intent)?)
}

pub fn rust_sign_intent(identity_id: String, upi_url: String) -> Result<String> {
    let state = VAULT_STATE.lock().unwrap();
    if let Some((_, vault, _, _)) = &*state {
        let priv_key = vault.private_keys.get(&identity_id)
            .ok_or_else(|| anyhow!("Identity not found"))?;
        
        let intent_data = parse_upi_url(&upi_url)?;
        let payload = IntentPayload {
            version: PROTOCOL_VERSION.to_string(),
            interaction_type: InteractionType::PaymentIntent,
            timestamp: SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs(),
            upi_data: intent_data,
        };

        let message = serde_json::to_string(&payload)?;
        let signature = sign_with_key(priv_key, message.as_bytes())?;
        
        let signed = SignedIntent {
            payload,
            // Uses fully qualified hex crate to avoid scope issues
            signature_hex: ::hex::encode(signature),
            signer_did: format!("did:satya:{}", identity_id),
        };

        Ok(serde_json::to_string(&signed)?)
    } else { Err(anyhow!("Vault Locked")) }
}

pub fn rust_publish_to_nostr(signed_json: String) -> Result<bool> {
    let rt = tokio::runtime::Builder::new_current_thread().enable_all().build()?;
    rt.block_on(async {
        let my_keys = Keys::generate();
        let client = Client::new(&my_keys);
        client.add_relay("wss://relay.damus.io").await?;
        client.connect().await;
        
        // Using .to_event() for nostr-sdk 0.26 compliance
        let event = EventBuilder::new(Kind::from(29001), signed_json, Vec::<Tag>::new())
            .to_event(&my_keys)?;

        client.send_event(event).await?;
        client.disconnect().await?;
        Ok(true)
    })
}

pub fn rust_reset_vault(storage_path: String) -> Result<bool> {
    let mut state = VAULT_STATE.lock().unwrap();
    *state = None;
    let mut path = PathBuf::from(storage_path);
    path.push("satya_vault");
    if path.exists() {
        let ts = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs();
        fs::rename(&path, path.with_extension(format!("mismatch_{}", ts)))?;
    }
    Ok(true)
}