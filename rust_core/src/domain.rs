use serde::{Serialize, Deserialize};

pub const DEFAULT_S2_LEVEL: u8 = 12;
pub const PROTOCOL_VERSION: &str = "v1.0.0";

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SatyaIdentity {
    pub did: String,
    pub pub_key_hex: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub enum InteractionType {
    Payment,
    Labor,
    Task,
    Udhaar,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IntentPayload {
    pub version: String,
    pub timestamp: i64,
    pub interaction: InteractionType,
    pub amount_cents: Option<u64>,
    pub currency: String,
    pub metadata: String,
    pub geo_hash: String,
    pub counterparty_did: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SignedIntent {
    pub payload: IntentPayload,
    pub signature_hex: String,
    pub signer_did: String,
}

#[derive(Debug)]
pub enum SatyaError {
    KeyGenerationFailed,
    SigningFailed,
    SerializationError,
    DatabaseError,
}
