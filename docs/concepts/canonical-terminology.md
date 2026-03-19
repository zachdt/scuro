# Canonical Terminology

These terms are the SDK-facing vocabulary for Scuro. Node and Rust clients should use these names consistently in public APIs, typed models, and generated docs.

## Core Terms

- **Module**: A catalog entry that binds one controller, one engine, one engine type, one verifier bundle, one config hash, one developer reward rate, and one lifecycle status.
- **Controller**: The user-facing contract that gates launchability, calls shared settlement, and orchestrates engine lifecycle transitions.
- **Engine**: The rule-enforcing contract for a gameplay family. Engines never mint or burn SCU directly.
- **Verifier Bundle**: The contract that converts structured public inputs plus a Groth16 proof blob into a boolean verification result.
- **Engine Type**: A `bytes32` tag returned by `engineType()` and used to bind modules, expressions, and client-side routing.
- **Config Hash**: A `bytes32` deployment label stored in the catalog and intended for client-side compatibility checks.

## Session Terms

- **Expression Token**: The ERC721 developer attribution token minted in `DeveloperExpressionRegistry`.
- **Settlement Outcome**: The `(player, totalBurned, payout, completed)` tuple returned by solo engines for controller settlement.
- **Reward Epoch**: The rolling accounting window used by `DeveloperRewards`.
- **Timeout Deadline**: The unix timestamp after which the current player-clock phase can be force-resolved.
- **Play Reference (`playRef`)**: A client-supplied `bytes32` correlation key for solo games.
- **Preset**: A governed on-chain math/config package used by `SlotMachineEngine` to parameterize a slot spin.

## Mode-Specific Terms

- **Request**: The NumberPicker round identifier returned from `play()` / `requestPlay()`.
- **Spin**: The slot round identifier returned from `spin()` / `requestSpin()`.
- **Session**: A solo lifecycle identifier used by blackjack and PvP.
- **Tournament**: A reusable tournament configuration stored by `TournamentController`.
- **Game**: A concrete poker match instance tracked by `SingleDraw2To7Engine`.
- **Hand**: A single poker hand inside a game or one blackjack hand inside a blackjack session.
- **Phase**: The current gameplay stage encoded as an enum-backed `uint8`.
- **Coordinator**: The off-chain actor authorized to submit proof-backed transitions for poker and blackjack.

## Naming Guidance For SDKs

- Use `module_id`, `game_id`, `session_id`, `tournament_id`, `expression_token_id`, and `request_id` as external field names.
- Preserve on-chain enum names when exposing typed constants: `LIVE`, `RETIRED`, `DISABLED`, `AwaitingInitialDeal`, `AwaitingPlayerAction`, and so on.
- Treat `bytes32` identifiers as opaque values. SDKs may provide ergonomic helpers, but should not reinterpret them semantically unless the protocol explicitly documents the encoding.
- Use `reward_pool` for controller-level payout pools and `total_burned` for developer accrual activity.
