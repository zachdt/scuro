# Enum and Phase Mappings

Clients should use these mappings explicitly instead of inferring integer meanings from tests or source layout.

## `GameCatalog.GameMode`

| Value | Label |
| --- | --- |
| `0` | `Solo` |
| `1` | `PvP` |
| `2` | `Tournament` |

## `GameCatalog.ModuleStatus`

| Value | Label | Launch new sessions | Settle existing sessions |
| --- | --- | --- | --- |
| `0` | `LIVE` | yes | yes |
| `1` | `RETIRED` | no | yes |
| `2` | `DISABLED` | no | no |

## `SingleDeckBlackjackEngine.SessionPhase`

| Value | Label | Meaning |
| --- | --- | --- |
| `0` | `Inactive` | No session state yet |
| `1` | `AwaitingInitialDeal` | Waiting for coordinator init proof |
| `2` | `AwaitingPlayerAction` | Waiting for player action before `deadlineAt` |
| `3` | `AwaitingCoordinator` | Waiting for action or showdown proof |
| `4` | `Completed` | Session can be settled |

## `SingleDeckBlackjackEngine` action constants

| Value | Label |
| --- | --- |
| `1` | `ACTION_HIT` |
| `2` | `ACTION_STAND` |
| `3` | `ACTION_DOUBLE` |
| `4` | `ACTION_SPLIT` |

## `SingleDeckBlackjackEngine` action-mask flags

| Value | Label |
| --- | --- |
| `1` | `ALLOW_HIT` |
| `2` | `ALLOW_STAND` |
| `4` | `ALLOW_DOUBLE` |
| `8` | `ALLOW_SPLIT` |

## `SingleDraw2To7Engine.MatchState`

| Value | Label |
| --- | --- |
| `0` | `Inactive` |
| `1` | `Active` |
| `2` | `Completed` |

## `SingleDraw2To7Engine.HandPhase`

| Value | Label | Meaning |
| --- | --- | --- |
| `0` | `None` | Empty state |
| `1` | `AwaitingInitialDeal` | Waiting for initial proof |
| `2` | `PreDrawBetting` | First player-clock betting round |
| `3` | `DrawDeclaration` | Players declare discard masks |
| `4` | `DrawProofPending` | Coordinator must submit draw proofs |
| `5` | `PostDrawBetting` | Second player-clock betting round |
| `6` | `ShowdownProofPending` | Coordinator must submit showdown proof |
| `7` | `HandComplete` | Hand ended before next hand/bootstrap logic |

## Client Notes

- Treat unknown enum values as incompatible state and surface them as typed errors.
- Prefer typed wrappers around these values in both Node and Rust SDKs.
- Persist both the numeric value and the canonical label in indexed data so schema migrations remain explicit.
