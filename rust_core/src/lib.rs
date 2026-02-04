// Adding Persistence and Security
pub mod api;
pub mod crypto;
pub mod domain;
pub mod embeddings; /* [NEW] Semantic matching module */
pub mod parser;
pub mod persistence;
pub mod telemetry;
pub mod service;
pub mod spatial; /* [NEW] Expose spatial module for Phase 10 */

// The bridge_generated file is managed by flutter_rust_bridge_codegen
mod bridge_generated;