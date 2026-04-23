# Canonical Terminology

- **Module**: A catalog entry that binds one controller, one engine, one engine type, one config hash, one developer reward rate, and one lifecycle status.
- **Controller**: The player-facing contract that burns wagers, records expression attribution, and finalizes settlement.
- **Engine**: The gameplay contract that owns randomness requests and outcome calculation.
- **Expression**: A developer-owned ERC721 identity used for reward attribution.
- **Request**: A solo lifecycle identifier, such as a number-picker request id or slot spin id.
- **Preset**: A governed slot configuration registered on `SlotMachineEngine`.
- **Lifecycle status**: `LIVE`, `RETIRED`, or `DISABLED`.

External APIs should prefer snake_case names such as `module_id`, `request_id`, `spin_id`, `preset_id`, and `expression_token_id`.
