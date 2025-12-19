// Adding Persistence and Security
use argon2::{password_hash::{PasswordHasher, SaltString}, Argon2};
use chacha20poly1305::{aead::{Aead, KeyInit, Payload}, XChaCha20Poly1305, XNonce};
use zeroize::Zeroize;
use anyhow::{Result, anyhow};
use rand::RngCore;

#[derive(Zeroize)]
#[zeroize(drop)]
pub struct VaultKey([u8; 32]);

impl VaultKey {
    pub fn from_pin(pin: &str, salt: &[u8]) -> Result<Self> {
        let mut key = [0u8; 32];
        let salt_str = SaltString::encode_b64(salt).map_err(|_| anyhow!("Salt error"))?;
        let hash = Argon2::default().hash_password(pin.as_bytes(), &salt_str)
            .map_err(|e| anyhow!("KDF failed: {}", e))?;
        
        // PRINCIPAL FIX: Argon2 'hash' is a field (Option), not a method.
        let bytes = hash.hash.ok_or_else(|| anyhow!("No hash bytes generated"))?;
        key.copy_from_slice(&bytes.as_ref()[..32]);
        Ok(VaultKey(key))
    }
    pub fn as_slice(&self) -> &[u8] { &self.0 }
}

pub fn encrypt_with_binding(key: &VaultKey, hw_id: &[u8], plaintext: &[u8]) -> Result<Vec<u8>> {
    let cipher = XChaCha20Poly1305::new(key.as_slice().into());
    let mut nonce_bytes = [0u8; 24];
    rand::thread_rng().fill_bytes(&mut nonce_bytes);
    let ciphertext = cipher.encrypt(XNonce::from_slice(&nonce_bytes), Payload { msg: plaintext, aad: hw_id })
        .map_err(|e| anyhow!("Encryption error: {}", e))?;
    let mut output = nonce_bytes.to_vec();
    output.extend(ciphertext);
    Ok(output)
}

pub fn decrypt_with_binding(key: &VaultKey, hw_id: &[u8], data: &[u8]) -> Result<Vec<u8>> {
    if data.len() < 24 { return Err(anyhow!("Invalid ciphertext")); }
    let cipher = XChaCha20Poly1305::new(key.as_slice().into());
    let (nonce, ciphertext) = data.split_at(24);
    cipher.decrypt(XNonce::from_slice(nonce), Payload { msg: ciphertext, aad: hw_id })
        .map_err(|_| anyhow!("Hardware/PIN Mismatch: Unauthorized access"))
}