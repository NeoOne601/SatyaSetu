/**
 * FILE: rust_core/src/domain.rs
 * VERSION: 2.0.1
 * PURPOSE: Extended domain for Ledger Verification.
 */

use serde::{Deserialize, Serialize};

pub const PROTOCOL_VERSION: &str = "1.0.0";

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

#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum InteractionType {
    PaymentIntent,
    IdentityVerification,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct IntentPayload {
    pub version: String,
    pub interaction_type: InteractionType,
    pub timestamp: u64,
    pub upi_data: UpiIntent,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct SignedIntent {
    pub payload: IntentPayload,
    pub signature_hex: String, 
    pub signer_did: String,
    #[serde(default)]
    pub is_verified: bool, 
}