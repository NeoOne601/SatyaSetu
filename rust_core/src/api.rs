/**
 * FILE: rust_core/src/api.rs
 * VERSION: 2.1.2
 * PHASE: Phase 9.1 (Runtime Stability)
 * GOAL: Maintain persistent relay connections and prevent 'No Reactor' panics.
 * FIX: Implemented a global STATIC_RUNTIME to keep the Tokio reactor alive.
 */

use crate::persistence::{VaultManager, SatyaVault};
use crate::crypto::{VaultKey, sign_with_key, verify_with_key};
use crate::domain::{SatyaIdentity, SignedIntent, IntentPayload, InteractionType, PROTOCOL_VERSION};
use crate::parser::parse_upi_url;
use anyhow::{Result, anyhow};
use std::sync::Mutex;
use once_cell::sync::Lazy;
use nostr_sdk::prelude::{Keys, Client, EventBuilder, Kind, Tag, Filter, Options}; 
use std::time::{SystemTime, UNIX_EPOCH, Duration};
use std::path::PathBuf;
use std::fs;
use uuid::Uuid;
use tokio::runtime::Runtime;

// Cryptographic trait disambiguation
use hmac::Mac; 
use sha2::Sha512;

// Persistent Global Runtime and Client
static STATIC_RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("Failed to create Tokio Runtime")
});

static NOSTR_CLIENT: Lazy<Mutex<Option<Client>>> = Lazy::new(|| Mutex::new(None));

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
            
            // Initialize Swarm Client within the Persistent Runtime
            let mut client_lock = NOSTR_CLIENT.lock().unwrap();
            if client_lock.is_none() {
                let _guard = STATIC_RUNTIME.enter();
                let my_keys = Keys::generate();
                let opts = Options::new().wait_for_send(false);
                let client = Client::with_opts(&my_keys, opts);
                
                STATIC_RUNTIME.block_on(async {
                    let _ = client.add_relay("wss://relay.damus.io").await;
                    let _ = client.add_relay("wss://relay.nostr.band").await;
                    client.connect().await;
                });
                *client_lock = Some(client);
            }
            
            Ok(true)
        },
        Err(e) => Err(anyhow!("{}", e))
    }
}

pub fn rust_create_identity(label: String) -> Result<SatyaIdentity> {
    let mut state = VAULT_STATE.lock().unwrap();
    if let Some((manager, vault, pin, hw_id)) = &mut *state {
        let index = vault.identities.len();
        // Explicit trait usage for derivation
        let mut mac = <hmac::SimpleHmac<Sha512> as hmac::Mac>::new_from_slice(&vault.master_seed)
            .map_err(|_| anyhow!("Derivation Error"))?;
        mac.update(format!("satya_identity_{}", index).as_bytes());
        let result = mac.finalize().into_bytes();
        let priv_key = result[..32].to_vec();
        
        let id_uuid = Uuid::new_v4().to_string();
        let new_id = SatyaIdentity { id: id_uuid.clone(), label, did: format!("did:satya:{}", id_uuid) };
        
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
        let priv_key = vault.private_keys.get(&identity_id).ok_or_else(|| anyhow!("Identity not found"))?;
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
            signature_hex: hex::encode(signature), 
            signer_did: format!("did:satya:{}", identity_id),
            is_verified: true 
        };
        Ok(serde_json::to_string(&signed)?)
    } else { Err(anyhow!("Vault Locked")) }
}

pub fn rust_publish_to_nostr(signed_json: String) -> Result<bool> {
    let client_lock = NOSTR_CLIENT.lock().unwrap();
    if let Some(client) = &*client_lock {
        let _guard = STATIC_RUNTIME.enter();
        STATIC_RUNTIME.block_on(async {
            let keys = client.keys().await;
            let event = EventBuilder::new(Kind::from(29001), signed_json, Vec::new()).to_event(&keys).unwrap();
            client.send_event(event).await?;
            Ok(true)
        })
    } else { Err(anyhow!("Network Client Not Initialized")) }
}

pub fn rust_fetch_interaction_history() -> Result<Vec<String>> {
    let client_lock = NOSTR_CLIENT.lock().unwrap();
    if let Some(client) = &*client_lock {
        let _guard = STATIC_RUNTIME.enter();
        STATIC_RUNTIME.block_on(async {
            let filter = Filter::new().kind(Kind::from(29001)).limit(20);
            let events = client.get_events_of(vec![filter], Some(Duration::from_secs(10))).await?;
            let mut history = Vec::new();
            for event in events {
                if let Ok(mut signed) = serde_json::from_str::<SignedIntent>(&event.content) {
                    signed.is_verified = true; 
                    history.push(serde_json::to_string(&signed)?);
                }
            }
            Ok(history)
        })
    } else { Err(anyhow!("Network Client Not Initialized")) }
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