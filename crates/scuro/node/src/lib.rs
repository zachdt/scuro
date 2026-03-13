//! Scuro node launcher and protocol seams.

#![cfg_attr(not(test), warn(unused_crate_dependencies))]

use clap::Parser;
use reth_ethereum::{
    chainspec::ChainSpec,
    evm::EthEvmConfig,
    node::{
        api::{FullNodeTypes, NodeTypes},
        builder::{components::ExecutorBuilder, BuilderContext},
        node::EthereumAddOns,
        EthereumNode,
    },
    EthPrimitives,
};
use reth_ethereum_cli::interface::Cli;
use scuro_chainspec::ScuroChainSpecParser;
use scuro_config::ScuroProtocolConfig;
use tracing::info;

/// Scuro-specific protocol hook registry. In milestone 1 these hooks are intentionally inert and
/// only reserve the extension seam where native verifier/registry execution will land next.
#[derive(Debug, Clone, Default)]
pub struct ScuroProtocolHooks {
    config: ScuroProtocolConfig,
}

impl ScuroProtocolHooks {
    /// Creates hooks from an explicit protocol configuration.
    pub const fn new(config: ScuroProtocolConfig) -> Self {
        Self { config }
    }

    /// Returns the protocol configuration carried by these hooks.
    pub const fn config(&self) -> &ScuroProtocolConfig {
        &self.config
    }
}

/// Executor builder that reserves Scuro-native execution seams while still using the default
/// Ethereum EVM behavior in milestone 1.
#[derive(Debug, Clone, Default)]
pub struct ScuroExecutorBuilder {
    hooks: ScuroProtocolHooks,
}

impl ScuroExecutorBuilder {
    /// Creates a new builder using the supplied hook configuration.
    pub const fn new(hooks: ScuroProtocolHooks) -> Self {
        Self { hooks }
    }
}

impl<Node> ExecutorBuilder<Node> for ScuroExecutorBuilder
where
    Node: FullNodeTypes<Types: NodeTypes<ChainSpec = ChainSpec, Primitives = EthPrimitives>>,
{
    type EVM = EthEvmConfig<ChainSpec>;

    async fn build_evm(self, ctx: &BuilderContext<Node>) -> eyre::Result<Self::EVM> {
        info!(
            target: "scuro::node",
            hooks = ?self.hooks,
            chain_id = ctx.chain_spec().chain().id(),
            "Building Scuro EVM hooks"
        );

        Ok(EthEvmConfig::new(ctx.chain_spec()))
    }
}

/// Parses CLI arguments and launches `scuro-node`.
pub fn entrypoint() -> eyre::Result<()> {
    Cli::<ScuroChainSpecParser>::parse().run(|builder, _| async move {
        let hooks = ScuroProtocolHooks::default();
        info!(target: "scuro::node", hooks = ?hooks, "Launching Scuro node");

        let handle = builder
            .with_types::<EthereumNode>()
            .with_components(EthereumNode::components().executor(ScuroExecutorBuilder::new(hooks)))
            .with_add_ons(EthereumAddOns::default())
            .launch()
            .await?;

        handle.wait_for_node_exit().await
    })
}
