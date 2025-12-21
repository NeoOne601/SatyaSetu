/**
 * PROJECT SATYA: RUST CORE ENGINE
 * ===============================
 * PHASE: 5.0 (The Signed Interaction)
 * VERSION: 1.2.0
 * STATUS: STABLE (Secret Storage Active)
 * DESCRIPTION:
 * Manages atomic binary file operations. Implements the storage schema 
 * for both identity metadata and secret material (Ed25519 private keys).
 * CHANGE LOG:
 * - Phase 3.2: Initial VaultManager using bincode.
 * - Phase 4.0: Standardized Phase headers.
 * - Phase 5.0: Secret Material storage (HashMap) implemented.
 */

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use crate::domain::SatyaIdentity;
use crate::crypto::{VaultKey, encrypt_with_binding, decrypt_with_binding};
use anyhow::{Result, Context};
use std::fs;
use std::path::PathBuf;

#[derive(Serialize, Deserialize, Default)]
pub struct SatyaVault {
    pub version: u32,
    pub identities: Vec<SatyaIdentity>,
    /// Secure map of Identity UUID -> Private Signing Key
    pub private_keys: HashMap<String, Vec<u8>>,
}

pub struct VaultManager {
    storage_path: PathBuf,
}

impl VaultManager {
    pub fn new(base_path: &str) -> Self {
        let mut path = PathBuf::from(base_path);
        path.push("satya_vault/vault.bin");
        let _ = fs::create_dir_all(path.parent().unwrap());
        Self { storage_path: path }
    }

    pub fn atomic_save(&self, key: &VaultKey, hw_id: &[u8], vault: &SatyaVault) -> Result<()> {
        let encoded = bincode::serialize(vault).context("Serialization error")?;
        let encrypted = encrypt_with_binding(key, hw_id, &encoded)?;
        let tmp_path = self.storage_path.with_extension("tmp");
        fs::write(&tmp_path, encrypted)?;
        fs::rename(&tmp_path, &self.storage_path)?; 
        Ok(())
    }

    pub fn load(&self, key: &VaultKey, hw_id: &[u8]) -> Result<SatyaVault> {
        if !self.storage_path.exists() { return Ok(SatyaVault::default()); }
        let encrypted = fs::read(&self.storage_path)?;
        let decrypted = decrypt_with_binding(key, hw_id, &encrypted)?;
        let vault: SatyaVault = bincode::deserialize(&decrypted)?;
        Ok(vault)
    }
}