# Scuro Documentation

Welcome to the Scuro developer documentation. This directory contains in-depth guides and technical specifications designed to help you understand, build, and extend the Scuro protocol.

If you are looking for a high-level overview, please start with the [Root README](../README.md).

## Technical Guides

- **[Protocol Architecture](./protocol-architecture.md)**: Explore the inner workings of Scuro, including the shared settlement layer, controller/engine architecture, and value-flow diagrams.
- **[Game Module User Flows](./game-module-user-flows.md)**: Follow detailed, module-by-module sequence diagrams for NumberPicker, Tournament poker, PvP poker, and Blackjack.
- **[Local Deployment & Testing](./local-deployment-testing.md)**: A practical guide to setting up your environment, building the protocol, and running the comprehensive test suite.
- **[E2E Scenario Matrix](../test/e2e/MATRIX.md)**: Review the detailed mapping of user journeys and edge cases to our automated end-to-end tests.

## Recommended Reading Order

1.  **Understand the Core**: Start with [Protocol Architecture](./protocol-architecture.md) to grasp how Scuro standardizes economic infrastructure across different games.
2.  **Trace the Runtime Paths**: Use [Game Module User Flows](./game-module-user-flows.md) to inspect the exact controller, engine, verifier, and settlement flow for each shipped module.
3.  **Get Hands-On**: Use the [Local Deployment and Testing](./local-deployment-testing.md) guide to build the protocol and run a smoke test.
4.  **Verify & Extend**: Consult the [E2E Scenario Matrix](../test/e2e/MATRIX.md) when evaluating coverage for new features or investigating specific protocol behaviors.
