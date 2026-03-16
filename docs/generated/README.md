# Generated Metadata

These files are the machine-readable companion to the human docs. They are intended to seed Node and Rust API generation, manifest loading, event decoding, and proof-input helpers.

## Files

- `protocol-manifest.json`: the canonical SDK-facing manifest
- `protocol-manifest.schema.json`: the manifest shape contract
- `event-signatures.json`: per-surface event signature inventory
- `enum-labels.json`: explicit enum and constant label mappings
- `proof-inputs.json`: ordered proof-input field names for poker and blackjack
- `contracts/*.abi.json`: canonical ABIs copied from Foundry build artifacts

## Regeneration

```bash
forge build --offline
ruby script/docs/generate_protocol_docs_metadata.rb
```

## Validation

```bash
ruby script/docs/check_sdk_docs_coverage.rb
node script/docs/smoke_manifest_node.mjs
rustc script/docs/smoke_manifest_rust.rs -o /tmp/scuro_manifest_smoke && /tmp/scuro_manifest_smoke
```
