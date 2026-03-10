# Scuro Docs

This directory holds the focused protocol and developer guides that sit behind the root [README](../README.md).

Start here when you need implementation detail that does not belong on the external project overview.

## Guides

- [Protocol architecture](./protocol-architecture.md): canonical system diagram, layer-by-layer component breakdown, operational notes, and code map.
- [Local deployment and testing](./local-deployment-testing.md): prerequisites, build and zk commands, suite selection, manual deployment, and deploy smoke workflow.
- [E2E scenario matrix](../test/e2e/MATRIX.md): scenario-to-test mapping used as the end-to-end completeness gate.

## Suggested Reading Order

1. Read [Protocol architecture](./protocol-architecture.md) to understand the shared settlement and controller/engine model.
2. Use [Local deployment and testing](./local-deployment-testing.md) when you need to build, validate, deploy, or run targeted suites.
3. Use the [E2E scenario matrix](../test/e2e/MATRIX.md) when evaluating whether a flow or abuse path is already covered.
