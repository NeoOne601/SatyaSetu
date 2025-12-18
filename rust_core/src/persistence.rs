use rusqlite::{params, Connection, Result};
use crate::domain::{SignedIntent, SatyaError};

pub struct Database;

impl Database {
    fn get_conn() -> Result<Connection> {
        Connection::open("satya_ledger.db")
    }

    pub fn init() -> Result<()> {
        let conn = Self::get_conn()?;
        conn.execute(
            "CREATE TABLE IF NOT EXISTS ledger (
                id INTEGER PRIMARY KEY,
                timestamp INTEGER,
                interaction_type TEXT,
                amount INTEGER,
                counterparty TEXT,
                signature TEXT,
                full_json TEXT
            )",
            [],
        )?;
        Ok(())
    }

    pub fn save_intent(intent: &SignedIntent) -> Result<(), SatyaError> {
        let conn = Self::get_conn().map_err(|_| SatyaError::DatabaseError)?;
        let json = serde_json::to_string(intent).map_err(|_| SatyaError::SerializationError)?;
        
        conn.execute(
            "INSERT INTO ledger (timestamp, interaction_type, amount, counterparty, signature, full_json)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                intent.payload.timestamp,
                format!("{:?}", intent.payload.interaction),
                intent.payload.amount_cents,
                intent.payload.counterparty_did,
                intent.signature_hex,
                json
            ],
        ).map_err(|_| SatyaError::DatabaseError)?;
        Ok(())
    }
}
