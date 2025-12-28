/**
 * FILE: rust_core/src/crypto.rs
 * VERSION: 1.7.9
 * PHASE: Phase 7
 * DESCRIPTION: Core cryptographic primitives (Argon2, ChaCha20, Ed25519).
 */

use argon2::{
    password_hash::{PasswordHasher, SaltString},
    Argon2,
};
use chacha20poly1305::{
    aead::{Aead, KeyInit},
    ChaCha20Poly1305, Nonce,
};
use anyhow::{Result, anyhow};
use ed25519_dalek::{Keypair, Signer, SecretKey, PublicKey};

pub struct VaultKey([u8; 32]);

impl VaultKey {
    pub fn from_pin(pin: &str, salt: &[u8]) -> Result<Self> {
        let argon2 = Argon2::default();
        let salt_string = SaltString::encode_b64(salt).map_err(|_| anyhow!("Salt error"))?;
        let hash = argon2.hash_password(pin.as_bytes(), &salt_string)
            .map_err(|_| anyhow!("Argon2 error"))?;
        
        let output = hash.hash.ok_or_else(|| anyhow!("Hash extraction failed"))?;
        
        let mut key = [0u8; 32];
        let len = std::cmp::min(output.len(), 32);
        key[..len].copy_from_slice(&output.as_ref()[..len]);
        Ok(VaultKey(key))
    }
}

pub fn encrypt_with_binding(key: &VaultKey, hw_id: &[u8], data: &[u8]) -> Result<Vec<u8>> {
    let cipher = ChaCha20Poly1305::new(&key.0.into());
    let mut nonce_bytes = [0u8; 12];
    let binding = ring::digest::digest(&ring::digest::SHA256, hw_id);
    nonce_bytes.copy_from_slice(&binding.as_ref()[..12]);
    let nonce = Nonce::from_slice(&nonce_bytes);
    cipher.encrypt(nonce, data).map_err(|_| anyhow!("Encryption failed"))
}

pub fn decrypt_with_binding(key: &VaultKey, hw_id: &[u8], data: &[u8]) -> Result<Vec<u8>> {
    let cipher = ChaCha20Poly1305::new(&key.0.into());
    let mut nonce_bytes = [0u8; 12];
    let binding = ring::digest::digest(&ring::digest::SHA256, hw_id);
    nonce_bytes.copy_from_slice(&binding.as_ref()[..12]);
    let nonce = Nonce::from_slice(&nonce_bytes);
    cipher.decrypt(nonce, data).map_err(|_| anyhow!("Decryption failed"))
}

pub fn sign_with_key(priv_key: &[u8], message: &[u8]) -> Result<Vec<u8>> {
    let secret = SecretKey::from_bytes(priv_key).map_err(|_| anyhow!("Invalid secret"))?;
    let public: PublicKey = (&secret).into();
    let keypair = Keypair { secret, public };
    let signature = keypair.sign(message);
    Ok(signature.to_bytes().to_vec())
}