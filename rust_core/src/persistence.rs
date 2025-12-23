/**
 * PROJECT SATYA: RUST CORE ENGINE
 * ===============================
 * PHASE: 6.7 (Resilient Trinity Baseline)
 * VERSION: 1.6.7
 * STATUS: STABLE (macOS Forensic Fix)
 * DESCRIPTION:
 * Manages vault file operations. Handles 'lazy' filesystem states 
 * common in sandboxed macOS environments.
 */

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use crate::domain::SatyaIdentity;
use crate::crypto::{VaultKey, encrypt_with_binding, decrypt_with_binding};
use anyhow::{Result, anyhow, Context};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Serialize, Deserialize, Default)]
pub struct SatyaVault {
    pub version: u32,
    pub identities: Vec<SatyaIdentity>,
    pub private_keys: HashMap<String, Vec<u8>>,
}

pub struct VaultManager {
    storage_path: PathBuf,
}

impl VaultManager {
    pub fn new(base_path: &str) -> Self {
        let mut path = PathBuf::from(base_path);
        path.push("satya_vault/vault.bin");
        // Ensure the container exists
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
        // PRINCIPAL FIX: If file is missing or effectively empty (0 bytes), return a clean vault
        if !self.storage_path.exists() {
            return Ok(SatyaVault::default());
        }
        
        let metadata = fs::metadata(&self.storage_path)?;
        if metadata.len() == 0 {
            return Ok(SatyaVault::default());
        }

        let encrypted = fs::read(&self.storage_path)?;
        let decrypted = decrypt_with_binding(key, hw_id, &encrypted)
            .map_err(|_| anyhow!("Hardware/PIN Mismatch"))?;
            
        let vault: SatyaVault = bincode::deserialize(&decrypted)
            .context("Vault corruption detected")?;
        Ok(vault)
    }
}