//! Scuro devnet smoke tests.

use alloy_eips::eip2718::Encodable2718;
use alloy_primitives::{b256, hex};
use futures_util::StreamExt;
use reth_node_api::{BlockBody, FullNodeComponents};
use reth_node_builder::{rpc::RethRpcAddOns, FullNode, NodeBuilder, NodeConfig, NodeHandle};
use reth_node_ethereum::{node::EthereumAddOns, EthereumNode};
use reth_provider::{providers::BlockchainProvider, CanonStateSubscriptions};
use reth_rpc_eth_api::helpers::EthTransactions;
use reth_tasks::Runtime;
use scuro_chainspec::SCURO_DEV;
use scuro_node::ScuroExecutorBuilder;

#[tokio::test]
async fn scuro_dev_chain_boots_and_mines_a_transaction() -> eyre::Result<()> {
    reth_tracing::init_test_tracing();
    let runtime = Runtime::with_existing_handle(tokio::runtime::Handle::current())?;

    let node_config = NodeConfig::test().with_chain(SCURO_DEV.clone()).dev();
    let NodeHandle { node, .. } = NodeBuilder::new(node_config)
        .testing_node(runtime)
        .with_types_and_provider::<EthereumNode, BlockchainProvider<_>>()
        .with_components(EthereumNode::components().executor(ScuroExecutorBuilder::default()))
        .with_add_ons(EthereumAddOns::default())
        .launch_with_debug_capabilities()
        .await?;

    assert_chain_advances(&node).await;
    Ok(())
}

async fn assert_chain_advances<N, AddOns>(node: &FullNode<N, AddOns>)
where
    N: FullNodeComponents<Provider: CanonStateSubscriptions>,
    AddOns: RethRpcAddOns<N, EthApi: EthTransactions>,
{
    let mut notifications = node.provider.canonical_state_stream();

    let raw_tx = hex!(
        "02f873827a6a808477359400847735940082520894ab0840c0e43688012c1adb0f5e3fc665188f83d2870aa87bee53800080c080a005eaf71ff7faba01538fb95dff36fe0485dd21713186103883c8c3c6f429d83da00e216fb5a97807be41316c07468e5e9ca409b0007cfa98d3f817638bf391621c"
    );

    let hash = node.rpc_registry.eth_api().send_raw_transaction(raw_tx.into()).await.unwrap();

    let expected = b256!("0xe5540b9e514a098548365e16946f52c2255d6cd0f9c29d0d21666b7222db137a");
    assert_eq!(hash, expected);

    let head = notifications.next().await.unwrap();
    let tx = &head.tip().body().transactions()[0];
    assert_eq!(tx.trie_hash(), hash);
}
