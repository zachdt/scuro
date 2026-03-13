//! Scuro chain spec helpers.

#![cfg_attr(not(test), warn(unused_crate_dependencies))]

use alloy_genesis::Genesis;
use alloy_primitives::U256;
use eyre::Result;
use reth_chainspec::{
    make_genesis_header, BaseFeeParams, BaseFeeParamsKind, Chain, ChainSpec, DEV_HARDFORKS,
    HOLESKY, HOODI, MAINNET, SEPOLIA,
};
use reth_cli::chainspec::{parse_genesis, ChainSpecParser};
use reth_primitives::SealedHeader;
use scuro_config::ScuroProtocolConfig;
use serde::{Deserialize, Serialize};
use std::sync::{Arc, LazyLock};

/// Local Scuro devnet chain id.
pub const SCURO_DEV_CHAIN_ID: u64 = 31_338;

/// Supported Scuro node chain aliases. `dev` intentionally resolves to Scuro's devnet.
pub const SUPPORTED_CHAINS: &[&str] =
    &["scuro-dev", "dev", "mainnet", "sepolia", "holesky", "hoodi"];

/// Scuro-specific genesis metadata.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScuroGenesisConfig {
    /// Human-readable network name.
    pub network: String,
    /// EVM chain id.
    pub chain_id: u64,
}

impl ScuroGenesisConfig {
    /// Returns the default Scuro development genesis metadata.
    pub fn dev() -> Self {
        Self { network: "scuro-dev".to_string(), chain_id: SCURO_DEV_CHAIN_ID }
    }
}

/// High-level Scuro chain spec wrapper. The runtime currently consumes the inner `reth`
/// `ChainSpec`, while this wrapper preserves Scuro-specific metadata and the future protocol
/// configuration seam.
#[derive(Debug, Clone)]
pub struct ScuroChainSpec {
    inner: Arc<ChainSpec>,
    genesis_config: ScuroGenesisConfig,
    protocol_config: ScuroProtocolConfig,
}

impl ScuroChainSpec {
    /// Creates the default Scuro dev chain spec.
    pub fn dev() -> Self {
        let genesis: Genesis = serde_json::from_str(include_str!("../res/genesis/scuro-dev.json"))
            .expect("scuro dev genesis json must deserialize");
        let hardforks = DEV_HARDFORKS.clone();
        let inner = Arc::new(ChainSpec {
            chain: Chain::from_id(SCURO_DEV_CHAIN_ID),
            genesis_header: SealedHeader::seal_slow(make_genesis_header(&genesis, &hardforks)),
            genesis,
            paris_block_and_final_difficulty: Some((0, U256::ZERO)),
            hardforks,
            base_fee_params: BaseFeeParamsKind::Constant(BaseFeeParams::ethereum()),
            deposit_contract: None,
            ..Default::default()
        });

        Self {
            inner,
            genesis_config: ScuroGenesisConfig::dev(),
            protocol_config: ScuroProtocolConfig::default(),
        }
    }

    /// Returns the underlying `reth` chain spec.
    pub fn inner(&self) -> Arc<ChainSpec> {
        self.inner.clone()
    }

    /// Returns the Scuro-specific genesis metadata.
    pub const fn genesis_config(&self) -> &ScuroGenesisConfig {
        &self.genesis_config
    }

    /// Returns the Scuro protocol configuration seam.
    pub const fn protocol_config(&self) -> &ScuroProtocolConfig {
        &self.protocol_config
    }
}

/// Lazily-initialized Scuro dev chain spec.
pub static SCURO_DEV: LazyLock<Arc<ChainSpec>> = LazyLock::new(|| ScuroChainSpec::dev().inner());

/// Parser for `scuro-node`.
#[derive(Debug, Clone, Default)]
#[non_exhaustive]
pub struct ScuroChainSpecParser;

impl ChainSpecParser for ScuroChainSpecParser {
    type ChainSpec = ChainSpec;

    const SUPPORTED_CHAINS: &'static [&'static str] = SUPPORTED_CHAINS;

    fn default_value() -> Option<&'static str> {
        Some("scuro-dev")
    }

    fn parse(s: &str) -> Result<Arc<ChainSpec>> {
        Ok(match s {
            "scuro-dev" | "dev" => SCURO_DEV.clone(),
            "mainnet" => MAINNET.clone(),
            "sepolia" => SEPOLIA.clone(),
            "holesky" => HOLESKY.clone(),
            "hoodi" => HOODI.clone(),
            _ => Arc::new(parse_genesis(s)?.into()),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dev_chain_uses_scuro_defaults() {
        let spec = ScuroChainSpec::dev();
        assert_eq!(spec.genesis_config().network, "scuro-dev");
        assert_eq!(spec.genesis_config().chain_id, SCURO_DEV_CHAIN_ID);
        assert_eq!(spec.inner().chain.id(), SCURO_DEV_CHAIN_ID);
        assert_eq!(spec.protocol_config(), &ScuroProtocolConfig::default());
    }

    #[test]
    fn parser_maps_aliases_and_known_networks() {
        assert_eq!(
            <ScuroChainSpecParser as ChainSpecParser>::parse("scuro-dev").unwrap().chain.id(),
            SCURO_DEV_CHAIN_ID
        );
        assert_eq!(
            <ScuroChainSpecParser as ChainSpecParser>::parse("dev").unwrap().chain.id(),
            SCURO_DEV_CHAIN_ID
        );
        assert_eq!(
            <ScuroChainSpecParser as ChainSpecParser>::parse("mainnet").unwrap().chain.id(),
            MAINNET.chain.id()
        );
    }

    #[test]
    fn parser_accepts_external_genesis_files() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("custom.json");
        std::fs::write(
            &path,
            r#"{
                "nonce":"0x0",
                "timestamp":"0x0",
                "extraData":"0x00",
                "gasLimit":"0x1c9c380",
                "difficulty":"0x0",
                "mixHash":"0x0000000000000000000000000000000000000000000000000000000000000000",
                "coinbase":"0x0000000000000000000000000000000000000000",
                "alloc":{},
                "number":"0x0",
                "gasUsed":"0x0",
                "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000000",
                "config":{
                    "chainId":31339,
                    "homesteadBlock":0,
                    "eip150Block":0,
                    "eip155Block":0,
                    "eip158Block":0,
                    "byzantiumBlock":0,
                    "constantinopleBlock":0,
                    "petersburgBlock":0,
                    "istanbulBlock":0,
                    "berlinBlock":0,
                    "londonBlock":0,
                    "terminalTotalDifficulty":0,
                    "terminalTotalDifficultyPassed":true,
                    "shanghaiTime":0
                }
            }"#,
        )
        .unwrap();

        let parsed =
            <ScuroChainSpecParser as ChainSpecParser>::parse(path.to_str().unwrap()).unwrap();
        assert_eq!(parsed.chain.id(), 31_339);
    }
}
