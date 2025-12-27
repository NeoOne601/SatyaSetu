/**
 * FILE: rust_core/src/service.rs
 * VERSION: 1.7.9
 * PHASE: Phase 7
 * DESCRIPTION: Helper logic for creating protocol-compliant payloads.
 */

use crate::domain::{IntentPayload, InteractionType, PROTOCOL_VERSION, UpiIntent};
use std::time::{SystemTime, UNIX_EPOCH};
use anyhow::Result;

pub struct InteractionService;

impl InteractionService {
    pub fn create_payment_payload(upi_data: UpiIntent) -> Result<IntentPayload> {
        Ok(IntentPayload {
            version: PROTOCOL_VERSION.to_string(),
            interaction_type: InteractionType::PaymentIntent,
            timestamp: SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs(),
            upi_data,
        })
    }
}