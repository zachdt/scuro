# Private AWS Testnet

The beta AWS stack is a single-host Scuro testnet for core, `NumberPicker`, and `SlotMachine`.

## Runtime Shape

- One EC2 host runs Anvil and the Bun operator API.
- Deployment jobs are asynchronous and persisted on disk.
- Remote smoke targets are direct operator calls for `number-picker` and `slot`.
- Public RPC through CloudFront is optional.

## Deploy Stages

`script/aws/deploy_staged.sh` runs:

1. `core`
2. `number-picker`
3. `slot`
4. `finalize`

Finalize mints and transfers the number-picker and slot expression tokens to `SOLO_DEVELOPER`.

## Operator Routes

- `GET /health`
- `GET /manifest`
- `GET /actors`
- `POST /deploy`
- `GET /deploy-jobs/:id`
- `POST /smoke/number-picker`
- `POST /smoke/slot`
- Snapshot import/export/restore routes used by release workflows

## Release Workflow

`.github/workflows/release-beta.yml` builds the host bundle, applies Terraform, deploys the protocol, checks the manifest, and runs snapshot-isolated smokes:

- `smoke-number-picker.json`
- `smoke-slot.json`

Useful local checks:

```bash
bun run --cwd ops/aws-testnet check
bun test --cwd ops/aws-testnet
bash script/aws/verify_local.sh
```
