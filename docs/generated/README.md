# Generated Metadata

These files are the machine-readable companion to the human docs. They seed SDK manifest loading, ABI binding generation, event decoding, deployment label discovery, and enum/constant display names.

## Files

- `protocol-manifest.json`: the canonical SDK-facing manifest
- `protocol-manifest.schema.json`: the manifest shape contract
- `event-signatures.json`: per-surface event signature inventory
- `enum-labels.json`: explicit enum and constant label mappings
- `contracts/*.abi.json`: canonical ABIs copied from Foundry build artifacts

Only the current contract and deployment metadata is generated.

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
