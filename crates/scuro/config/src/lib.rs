//! Scuro-specific protocol configuration.

#![cfg_attr(not(test), warn(unused_crate_dependencies))]

use serde::{Deserialize, Serialize};

/// Lifecycle mode for a reserved native protocol surface.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum ReservedSurfaceMode {
    /// The surface is intentionally inert in milestone 1.
    #[default]
    Reserved,
    /// The surface is disabled entirely.
    Disabled,
}

/// Scuro-owned protocol configuration that will eventually drive native chain features.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScuroProtocolConfig {
    /// Reserved slot for the native verifier integration.
    #[serde(default)]
    pub native_verifier: ReservedSurfaceMode,
    /// Reserved slot for the native verification-key registry integration.
    #[serde(default)]
    pub verifier_registry: ReservedSurfaceMode,
}

impl Default for ScuroProtocolConfig {
    fn default() -> Self {
        Self {
            native_verifier: ReservedSurfaceMode::Reserved,
            verifier_registry: ReservedSurfaceMode::Reserved,
        }
    }
}
