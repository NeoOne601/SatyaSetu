use crate::domain::{IntentPayload, InteractionType, SatyaIdentity, SignedIntent, SatyaError, PROTOCOL_VERSION};
use crate::crypto::CryptoProvider;
use crate::persistence::Database;
use ed25519_dalek::SigningKey;

pub struct TransactionService;

impl TransactionService {
    pub fn init_core() -> Result<(), SatyaError> {
        Database::init().map_err(|_| SatyaError::DatabaseError)
    }

    pub fn create_identity() -> Result<(SatyaIdentity, SigningKey), SatyaError> {
        CryptoProvider::generate_new_identity()
    }

    pub fn create_signed_transaction(
        signer_key: &SigningKey,
        interaction: InteractionType,
        amount_cents: Option<u64>,
        currency: String,
        metadata: String,
        geo_hash: String,
        counterparty_did: String,
    ) -> Result<SignedIntent, SatyaError> {

        let payload = IntentPayload {
            version: PROTOCOL_VERSION.to_string(),
            timestamp: chrono::Utc::now().timestamp(),
            interaction,
            amount_cents,
            currency,
            metadata,
            geo_hash,
            counterparty_did,
        };

        let payload_json = serde_json::to_string(&payload)
            .map_err(|_| SatyaError::SerializationError)?;
            
        let signature_hex = CryptoProvider::sign_data(signer_key, payload_json.as_bytes())?;
        
        let verifying_key = signer_key.verifying_key();
        let signer_pub_hex = hex::encode(verifying_key.to_bytes());

        let signed_intent = SignedIntent {
            payload,
            signature_hex,
            signer_did: format!("did:satya:{}", signer_pub_hex),
        };

        let _ = Database::save_intent(&signed_intent);

        Ok(signed_intent)
    }
}
