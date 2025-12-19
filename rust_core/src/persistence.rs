// Adding Persistence and Security
use serde::{Deserialize, Serialize};
use crate::domain::SatyaIdentity;
use crate::crypto::{VaultKey, encrypt_with_binding, decrypt_with_binding};
use anyhow::{Result, Context};
use std::fs;
use std::path::PathBuf;

#[derive(Serialize, Deserialize, Default)]
pub struct SatyaVault {
    pub version: u32,
    pub identities: Vec<SatyaIdentity>,
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
        let encoded = bincode::serialize(vault).context("Vault serialization failed")?;
        let encrypted = encrypt_with_binding(key, hw_id, &encoded)?;

        let tmp_path = self.storage_path.with_extension("tmp");
        fs::write(&tmp_path, encrypted)?;
        fs::rename(&tmp_path, &self.storage_path)?; // Atomic filesystem swap
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