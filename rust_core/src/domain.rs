// Adding Persistence and Security
use serde::{Deserialize, Serialize};

pub const PROTOCOL_VERSION: &str = "v1.0.0";

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct SatyaIdentity {
    pub id: String,
    pub label: String,
    pub did: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct UpiIntent {
    pub vpa: String,
    pub name: String,
    pub amount: String,
    pub currency: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub enum InteractionType {
    Payment, Labor, Task, Udhaar,
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

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum SatyaError {
    VaultLocked,
    DecryptionFailed,
    HardwareMismatch,
    SerializationError,
    DatabaseError, 
}