use crate::domain::{SatyaIdentity, SatyaError};
use ed25519_dalek::{SigningKey, Signer, Signature};
use rand::rngs::OsRng;
use rand::RngCore;

pub struct CryptoProvider;

impl CryptoProvider {
    pub fn generate_new_identity() -> Result<(SatyaIdentity, SigningKey), SatyaError> {
        let mut csprng = OsRng;
        let mut bytes = [0u8; 32];
        csprng.fill_bytes(&mut bytes);
        let signing_key = SigningKey::from_bytes(&bytes);
        let verifying_key = signing_key.verifying_key();
        
        let pub_hex = hex::encode(verifying_key.to_bytes());
        let did = format!("did:satya:{}", pub_hex);

        let identity = SatyaIdentity {
            did,
            pub_key_hex: pub_hex,
        };
        Ok((identity, signing_key))
    }

    pub fn sign_data(signing_key: &SigningKey, data: &[u8]) -> Result<String, SatyaError> {
        let signature: Signature = signing_key.sign(data);
        Ok(hex::encode(signature.to_bytes()))
    }
}
