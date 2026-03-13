## CI

The CI runs a couple of workflows:

### Code

- **[unit]**: Runs unit tests (tests in `src/`) and doc tests
- **[integration]**: Runs integration tests (tests in `tests/` and sync tests)
- **[scuro]**: Runs Scuro-specific linting, Rust tests, workspace compile checks, and the reference Solidity suite
- **[bench]**: Runs benchmarks
- **[sync]**: Runs sync tests
- **[stage]**: Runs all `stage run` commands

### Docs

- **[book]**: Builds, tests, and deploys the book.

### Meta
- **[release]**: Runs the release workflow
- **[release-dist]**: Publishes Reth to external package managers
- **[dependencies]**: Runs `cargo update` periodically to keep dependencies current
- **[stale]**: Marks issues as stale if there has been no activity
- **[docker]**: Publishes the Docker image.

### Integration Testing

- **[kurtosis]**: Spins up a Kurtosis testnet and runs Assertoor tests on Reth pairs.
- **[hive]**: Runs `ethereum/hive` tests.

### Linting and Checks

- **[lint]**: Lints code using `cargo clippy` and other checks
- **[lint-actions]**: Lints GitHub Actions workflows
- **[label-pr]**: Automatically labels PRs

### Scuro Notes

- The `scuro` workflow is the focused PR gate for the Scuro fork surfaces.
- The reference Solidity suite runs via `forge test --offline` because the reference tree should
  stay hermetic and plain `forge test` can pull in environment-dependent network behavior.

[unit]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/unit.yml
[integration]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/integration.yml
[scuro]: ../../.github/workflows/scuro.yml
[bench]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/bench.yml
[sync]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/sync.yml
[stage]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/stage.yml
[book]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/book.yml
[release]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/release.yml
[release-dist]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/release-dist.yml
[dependencies]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/dependencies.yml
[stale]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/stale.yml
[docker]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/docker.yml
[kurtosis]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/kurtosis.yml
[hive]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/hive.yml
[lint]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/lint.yml
[lint-actions]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/lint-actions.yml
[label-pr]: https://github.com/paradigmxyz/reth/blob/main/.github/workflows/label-pr.yml
