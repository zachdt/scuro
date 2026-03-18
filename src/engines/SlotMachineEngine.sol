// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {GameCatalog} from "../GameCatalog.sol";
import {ISoloLifecycleEngine} from "../interfaces/ISoloLifecycleEngine.sol";

/// @title Governed slot machine engine
/// @notice Resolves one atomic slot spin per request from a governed on-chain preset.
contract SlotMachineEngine is ISoloLifecycleEngine, AccessControl {
    bytes32 public constant ENGINE_TYPE = keccak256("SLOT_MACHINE");
    bytes32 public constant PRESET_MANAGER_ROLE = keccak256("PRESET_MANAGER_ROLE");

    uint8 public constant WAYS_LEFT_TO_RIGHT = 1;
    uint8 public constant VOL_LOW = 1;
    uint8 public constant VOL_MEDIUM = 2;
    uint8 public constant VOL_HIGH = 3;
    uint8 public constant VOL_EXTREME = 4;
    uint8 public constant STATUS_PENDING = 1;
    uint8 public constant STATUS_RESOLVED = 2;
    uint8 public constant MAX_REELS = 6;
    uint8 public constant MAX_ROWS = 4;
    uint8 public constant MAX_SUPPORTED_SYMBOLS = 16;
    uint8 public constant MAX_PAYTABLE_ENTRIES = 32;
    uint8 public constant MAX_PICK_AWARDS = 16;
    uint8 public constant MAX_HOLD_VALUES = 16;
    uint8 public constant MAX_JACKPOT_TIERS = 4;
    uint8 public constant MAX_TOTAL_EVENTS = 64;

    struct PresetConfig {
        uint8 volatilityTier;
        bytes32 configHash;
        uint8 reelCount;
        uint8 rowCount;
        uint8 waysMode;
        uint256 minStake;
        uint256 maxStake;
        uint256 maxPayoutMultiplierBps;
        uint16[] symbolIds;
        uint16 wildSymbolId;
        uint16 scatterSymbolId;
        uint16 bonusSymbolId;
        uint16 jackpotSymbolId;
        uint16[] reelWeightOffsets;
        uint16[] reelSymbolIds;
        uint16[] reelSymbolWeights;
        uint16[] paytableSymbolIds;
        uint8[] paytableMatchCounts;
        uint32[] paytableMultiplierBps;
        uint8 freeSpinTriggerCount;
        uint8[] freeSpinAwardCounts;
        uint8 maxFreeSpins;
        uint8 maxRetriggers;
        uint32 freeSpinMultiplierBps;
        uint8 pickTriggerCount;
        uint8 maxPickReveals;
        uint32[] pickAwardMultiplierBps;
        uint8 holdTriggerCount;
        uint8 holdBoardSize;
        uint8 initialRespins;
        uint8 maxRespins;
        uint32[] holdValueMultiplierBps;
        uint8[] jackpotTierIds;
        uint32[] jackpotAwardMultiplierBps;
        uint16[] jackpotTierWeights;
        uint8 maxTotalEvents;
    }

    struct PresetSummary {
        bool active;
        uint8 volatilityTier;
        bytes32 configHash;
        uint8 reelCount;
        uint8 rowCount;
        uint8 waysMode;
        uint256 minStake;
        uint256 maxStake;
        uint256 maxPayoutMultiplierBps;
        uint8 maxFreeSpins;
        uint8 maxRetriggers;
        uint8 maxPickReveals;
        uint8 maxRespins;
        uint8 maxTotalEvents;
    }

    struct Spin {
        address player;
        uint256 presetId;
        uint256 stake;
        bytes32 playRef;
        uint256 seed;
        uint256 finalPayout;
        uint8 status;
        bool resolved;
    }

    struct SpinResult {
        uint16[] baseGrid;
        uint16[] wayWinSymbolIds;
        uint8[] wayWinMatchCounts;
        uint16[] wayWinWayCounts;
        uint256[] wayWinPayouts;
        bool triggeredFreeSpins;
        bool triggeredPickBonus;
        bool triggeredHoldAndSpin;
        uint8 freeSpinCount;
        uint256 freeSpinPayout;
        uint256 pickBonusPayout;
        uint256 holdAndSpinPayout;
        uint8 jackpotTierHit;
        uint256 jackpotPayout;
        uint256 totalPayout;
    }

    struct EvaluationState {
        uint256 payout;
        uint8 eventCount;
    }

    struct BaseOutcome {
        uint256 payout;
        uint8 holdFillCount;
        bool triggeredFreeSpins;
        bool triggeredPickBonus;
        bool triggeredHoldAndSpin;
    }

    struct HoldSpinState {
        uint8 spinsRemaining;
        uint8 respinsUsed;
        uint8 filled;
        uint256 payout;
        uint8 jackpotTierHit;
        uint256 jackpotPayout;
    }

    GameCatalog internal immutable CATALOG;
    address public immutable VRF_COORDINATOR;
    uint256 public nextPresetId = 1;
    uint256 public totalSpins;
    uint256 public totalWagers;
    uint256 public totalPayouts;

    mapping(uint256 => PresetConfig) internal presets;
    mapping(uint256 => bool) public presetActive;
    mapping(uint256 => Spin) internal spins;
    mapping(uint256 => SpinResult) internal spinResults;

    event PresetRegistered(uint256 indexed presetId, uint8 volatilityTier, bytes32 configHash);
    event PresetActiveSet(uint256 indexed presetId, bool active);
    event SpinRequested(
        uint256 indexed spinId,
        address indexed player,
        uint256 indexed presetId,
        uint256 stake,
        bytes32 playRef
    );
    event BaseGameResolved(uint256 indexed spinId, uint256 payout, bool freeSpinsTriggered, bool pickTriggered, bool holdTriggered);
    event FreeSpinsResolved(uint256 indexed spinId, uint8 awardedSpins, uint256 payout, uint8 retriggersUsed);
    event PickBonusResolved(uint256 indexed spinId, uint8 reveals, uint256 payout);
    event HoldAndSpinResolved(uint256 indexed spinId, uint8 filled, uint8 respinsUsed, uint256 payout);
    event JackpotAwarded(uint256 indexed spinId, uint8 indexed tierId, uint256 payout);
    event SpinResolved(uint256 indexed spinId, uint256 payout, uint256 seed);

    constructor(address admin, address catalogAddress, address vrfCoordinatorAddress) {
        CATALOG = GameCatalog(catalogAddress);
        VRF_COORDINATOR = vrfCoordinatorAddress;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PRESET_MANAGER_ROLE, admin);
    }

    function catalog() public view returns (GameCatalog) {
        return CATALOG;
    }

    function engineType() external pure returns (bytes32) {
        return ENGINE_TYPE;
    }

    function registerPreset(PresetConfig calldata config) external onlyRole(PRESET_MANAGER_ROLE) returns (uint256 presetId) {
        _validatePreset(config);

        presetId = nextPresetId++;
        PresetConfig storage preset = presets[presetId];
        preset.volatilityTier = config.volatilityTier;
        preset.configHash = config.configHash;
        preset.reelCount = config.reelCount;
        preset.rowCount = config.rowCount;
        preset.waysMode = config.waysMode;
        preset.minStake = config.minStake;
        preset.maxStake = config.maxStake;
        preset.maxPayoutMultiplierBps = config.maxPayoutMultiplierBps;
        preset.wildSymbolId = config.wildSymbolId;
        preset.scatterSymbolId = config.scatterSymbolId;
        preset.bonusSymbolId = config.bonusSymbolId;
        preset.jackpotSymbolId = config.jackpotSymbolId;
        preset.freeSpinTriggerCount = config.freeSpinTriggerCount;
        preset.maxFreeSpins = config.maxFreeSpins;
        preset.maxRetriggers = config.maxRetriggers;
        preset.freeSpinMultiplierBps = config.freeSpinMultiplierBps;
        preset.pickTriggerCount = config.pickTriggerCount;
        preset.maxPickReveals = config.maxPickReveals;
        preset.holdTriggerCount = config.holdTriggerCount;
        preset.holdBoardSize = config.holdBoardSize;
        preset.initialRespins = config.initialRespins;
        preset.maxRespins = config.maxRespins;
        preset.maxTotalEvents = config.maxTotalEvents;

        _pushUint16Array(preset.symbolIds, config.symbolIds);
        _pushUint16Array(preset.reelWeightOffsets, config.reelWeightOffsets);
        _pushUint16Array(preset.reelSymbolIds, config.reelSymbolIds);
        _pushUint16Array(preset.reelSymbolWeights, config.reelSymbolWeights);
        _pushUint16Array(preset.paytableSymbolIds, config.paytableSymbolIds);
        _pushUint8Array(preset.paytableMatchCounts, config.paytableMatchCounts);
        _pushUint32Array(preset.paytableMultiplierBps, config.paytableMultiplierBps);
        _pushUint8Array(preset.freeSpinAwardCounts, config.freeSpinAwardCounts);
        _pushUint32Array(preset.pickAwardMultiplierBps, config.pickAwardMultiplierBps);
        _pushUint32Array(preset.holdValueMultiplierBps, config.holdValueMultiplierBps);
        _pushUint8Array(preset.jackpotTierIds, config.jackpotTierIds);
        _pushUint32Array(preset.jackpotAwardMultiplierBps, config.jackpotAwardMultiplierBps);
        _pushUint16Array(preset.jackpotTierWeights, config.jackpotTierWeights);

        presetActive[presetId] = true;
        emit PresetRegistered(presetId, config.volatilityTier, config.configHash);
    }

    function setPresetActive(uint256 presetId, bool active) external onlyRole(PRESET_MANAGER_ROLE) {
        require(presetId != 0 && presetId < nextPresetId, "SlotMachine: unknown preset");
        presetActive[presetId] = active;
        emit PresetActiveSet(presetId, active);
    }

    function requestSpin(address player, uint256 stake, uint256 presetId, bytes32 playRef) external returns (uint256 spinId) {
        require(CATALOG.isAuthorizedControllerForEngine(msg.sender, address(this)), "SlotMachine: not controller");
        PresetConfig storage preset = presets[presetId];
        require(presetActive[presetId], "SlotMachine: inactive preset");
        require(preset.configHash != bytes32(0), "SlotMachine: unknown preset");
        require(stake >= preset.minStake, "SlotMachine: stake too small");
        if (preset.maxStake != 0) {
            require(stake <= preset.maxStake, "SlotMachine: stake too large");
        }

        spinId = _getNextRequestId();
        spins[spinId] = Spin({
            player: player,
            presetId: presetId,
            stake: stake,
            playRef: playRef,
            seed: 0,
            finalPayout: 0,
            status: STATUS_PENDING,
            resolved: false
        });

        totalSpins += 1;
        totalWagers += stake;
        emit SpinRequested(spinId, player, presetId, stake, playRef);

        uint256 actualId = _requestRandomness();
        require(actualId == spinId, "SlotMachine: request mismatch");
    }

    function rawFulfillRandomWords(uint256 spinId, uint256[] memory randomWords) external {
        require(CATALOG.isSettlableEngine(address(this)), "SlotMachine: module inactive");
        require(msg.sender == VRF_COORDINATOR, "SlotMachine: bad coordinator");

        Spin storage spin = spins[spinId];
        require(spin.player != address(0), "SlotMachine: unknown spin");
        require(!spin.resolved, "SlotMachine: resolved");

        PresetConfig storage preset = presets[spin.presetId];
        uint256 seed = randomWords[0];
        spin.seed = seed;

        SpinResult storage result = spinResults[spinId];
        EvaluationState memory state;

        uint16[] memory grid = _generateGrid(preset, seed, 0);
        _replaceUint16Array(result.baseGrid, grid);
        BaseOutcome memory base = _resolveBaseOutcome(preset, spin.stake, grid, result);
        state.payout += base.payout;

        result.triggeredFreeSpins = base.triggeredFreeSpins;
        result.triggeredPickBonus = base.triggeredPickBonus;
        result.triggeredHoldAndSpin = base.triggeredHoldAndSpin;

        emit BaseGameResolved(
            spinId, state.payout, result.triggeredFreeSpins, result.triggeredPickBonus, result.triggeredHoldAndSpin
        );

        if (result.triggeredFreeSpins) {
            {
                (uint8 awardedSpins, uint256 payout, uint8 retriggersUsed, uint8 eventCount) =
                    _resolveFreeSpins(preset, spin.stake, seed, state.eventCount);
                result.freeSpinCount = awardedSpins;
                result.freeSpinPayout = payout;
                state.payout += payout;
                state.eventCount += eventCount;
                emit FreeSpinsResolved(spinId, awardedSpins, payout, retriggersUsed);
            }
        }

        if (result.triggeredPickBonus) {
            {
                (uint256 payout, uint8 reveals) = _resolvePickBonus(preset, spin.stake, seed, state.eventCount);
                result.pickBonusPayout = payout;
                state.payout += payout;
                state.eventCount += reveals;
                emit PickBonusResolved(spinId, reveals, payout);
            }
        }

        if (result.triggeredHoldAndSpin) {
            {
                (uint256 payout, uint8 filled, uint8 respinsUsed, uint8 jackpotTierHit, uint256 jackpotPayout, uint8 eventCount)
                = _resolveHoldAndSpin(preset, spin.stake, seed, state.eventCount, base.holdFillCount);
                result.holdAndSpinPayout = payout;
                result.jackpotTierHit = jackpotTierHit;
                result.jackpotPayout = jackpotPayout;
                state.payout += payout;
                state.eventCount += eventCount;
                emit HoldAndSpinResolved(spinId, filled, respinsUsed, payout);
                if (jackpotTierHit != 0) {
                    emit JackpotAwarded(spinId, jackpotTierHit, jackpotPayout);
                }
            }
        }

        require(state.eventCount <= preset.maxTotalEvents, "SlotMachine: event cap");
        require(state.payout <= (spin.stake * preset.maxPayoutMultiplierBps) / 10_000, "SlotMachine: payout cap");

        result.totalPayout = state.payout;
        spin.finalPayout = state.payout;
        spin.status = STATUS_RESOLVED;
        spin.resolved = true;
        totalPayouts += state.payout;

        emit SpinResolved(spinId, state.payout, seed);
    }

    function getPreset(uint256 presetId) external view returns (PresetConfig memory) {
        PresetConfig storage preset = presets[presetId];
        require(preset.configHash != bytes32(0), "SlotMachine: unknown preset");
        return preset;
    }

    function getPresetSummary(uint256 presetId) external view returns (PresetSummary memory summary) {
        PresetConfig storage preset = presets[presetId];
        require(preset.configHash != bytes32(0), "SlotMachine: unknown preset");
        summary = PresetSummary({
            active: presetActive[presetId],
            volatilityTier: preset.volatilityTier,
            configHash: preset.configHash,
            reelCount: preset.reelCount,
            rowCount: preset.rowCount,
            waysMode: preset.waysMode,
            minStake: preset.minStake,
            maxStake: preset.maxStake,
            maxPayoutMultiplierBps: preset.maxPayoutMultiplierBps,
            maxFreeSpins: preset.maxFreeSpins,
            maxRetriggers: preset.maxRetriggers,
            maxPickReveals: preset.maxPickReveals,
            maxRespins: preset.maxRespins,
            maxTotalEvents: preset.maxTotalEvents
        });
    }

    function getSpin(uint256 spinId) external view returns (Spin memory spin) {
        spin = spins[spinId];
        require(spin.player != address(0), "SlotMachine: unknown spin");
    }

    function getSpinResult(uint256 spinId) external view returns (SpinResult memory result) {
        Spin storage spin = spins[spinId];
        require(spin.player != address(0), "SlotMachine: unknown spin");
        result = spinResults[spinId];
    }

    function getSettlementOutcome(uint256 spinId)
        external
        view
        returns (address player, uint256 totalBurned, uint256 payout, bool completed)
    {
        Spin storage spin = spins[spinId];
        return (spin.player, spin.stake, spin.finalPayout, spin.resolved);
    }

    function _validatePreset(PresetConfig calldata config) internal pure {
        require(config.volatilityTier >= VOL_LOW && config.volatilityTier <= VOL_EXTREME, "SlotMachine: bad volatility");
        require(config.configHash != bytes32(0), "SlotMachine: zero hash");
        require(config.reelCount >= 3 && config.reelCount <= MAX_REELS, "SlotMachine: bad reels");
        require(config.rowCount >= 3 && config.rowCount <= MAX_ROWS, "SlotMachine: bad rows");
        require(config.waysMode == WAYS_LEFT_TO_RIGHT, "SlotMachine: bad ways mode");
        require(config.symbolIds.length > 0 && config.symbolIds.length <= MAX_SUPPORTED_SYMBOLS, "SlotMachine: bad symbols");
        require(config.reelWeightOffsets.length == config.reelCount + 1, "SlotMachine: bad offsets");
        require(config.reelWeightOffsets[0] == 0, "SlotMachine: bad offset start");
        require(config.reelWeightOffsets[config.reelWeightOffsets.length - 1] == config.reelSymbolIds.length, "SlotMachine: bad offset end");
        require(config.reelSymbolIds.length == config.reelSymbolWeights.length, "SlotMachine: bad weights");
        require(config.reelSymbolIds.length > 0, "SlotMachine: empty weights");
        require(config.paytableSymbolIds.length > 0 && config.paytableSymbolIds.length <= MAX_PAYTABLE_ENTRIES, "SlotMachine: bad paytable");
        require(
            config.paytableSymbolIds.length == config.paytableMatchCounts.length
                && config.paytableSymbolIds.length == config.paytableMultiplierBps.length,
            "SlotMachine: bad paytable arrays"
        );
        require(config.freeSpinAwardCounts.length > 0, "SlotMachine: bad free spins");
        require(config.maxFreeSpins > 0 && config.maxRetriggers <= config.maxFreeSpins, "SlotMachine: bad free spin caps");
        require(config.maxPickReveals > 0 && config.maxPickReveals <= MAX_PICK_AWARDS, "SlotMachine: bad pick caps");
        require(config.pickAwardMultiplierBps.length > 0 && config.pickAwardMultiplierBps.length <= MAX_PICK_AWARDS, "SlotMachine: bad pick awards");
        require(config.holdBoardSize > 0, "SlotMachine: bad hold board");
        require(config.holdValueMultiplierBps.length > 0 && config.holdValueMultiplierBps.length <= MAX_HOLD_VALUES, "SlotMachine: bad hold values");
        require(config.initialRespins > 0 && config.maxRespins > 0, "SlotMachine: bad respins");
        require(
            config.jackpotTierIds.length == config.jackpotAwardMultiplierBps.length
                && config.jackpotTierIds.length == config.jackpotTierWeights.length,
            "SlotMachine: bad jackpots"
        );
        require(config.jackpotTierIds.length <= MAX_JACKPOT_TIERS, "SlotMachine: too many jackpots");
        require(config.maxTotalEvents > 0 && config.maxTotalEvents <= MAX_TOTAL_EVENTS, "SlotMachine: bad max events");

        for (uint256 i = 0; i < config.reelSymbolWeights.length; i++) {
            require(config.reelSymbolWeights[i] > 0, "SlotMachine: zero reel weight");
        }
        for (uint256 i = 1; i < config.reelWeightOffsets.length; i++) {
            require(config.reelWeightOffsets[i] > config.reelWeightOffsets[i - 1], "SlotMachine: bad offsets");
        }
    }

    function _generateGrid(PresetConfig storage preset, uint256 seed, uint256 salt) internal view returns (uint16[] memory grid) {
        uint256 cells = uint256(preset.reelCount) * uint256(preset.rowCount);
        grid = new uint16[](cells);

        for (uint256 reel = 0; reel < preset.reelCount; reel++) {
            for (uint256 row = 0; row < preset.rowCount; row++) {
                grid[(reel * preset.rowCount) + row] = _drawWeightedSymbol(preset, seed, salt, reel, row);
            }
        }
    }

    function _drawWeightedSymbol(PresetConfig storage preset, uint256 seed, uint256 salt, uint256 reel, uint256 row)
        internal
        view
        returns (uint16 symbol)
    {
        uint256 start = preset.reelWeightOffsets[reel];
        uint256 end = preset.reelWeightOffsets[reel + 1];
        uint256 totalWeight;
        for (uint256 i = start; i < end; i++) {
            totalWeight += preset.reelSymbolWeights[i];
        }
        require(totalWeight > 0, "SlotMachine: zero total weight");

        uint256 random = uint256(keccak256(abi.encode(seed, salt, reel, row)));
        uint256 draw = random % totalWeight;
        uint256 running;
        for (uint256 i = start; i < end; i++) {
            running += preset.reelSymbolWeights[i];
            if (draw < running) {
                return preset.reelSymbolIds[i];
            }
        }
    }

    function _resolveBaseOutcome(PresetConfig storage preset, uint256 stake, uint16[] memory grid, SpinResult storage result)
        internal
        returns (BaseOutcome memory base)
    {
        base.payout = _evaluateWays(preset, stake, grid, result);

        uint256 scatterCount = _countSymbol(grid, preset.scatterSymbolId);
        uint256 bonusCount = _countSymbol(grid, preset.bonusSymbolId);
        uint256 jackpotCount = _countSymbol(grid, preset.jackpotSymbolId);

        base.triggeredFreeSpins = preset.freeSpinTriggerCount > 0 && scatterCount >= preset.freeSpinTriggerCount;
        base.triggeredPickBonus = preset.pickTriggerCount > 0 && bonusCount >= preset.pickTriggerCount;
        base.triggeredHoldAndSpin = preset.holdTriggerCount > 0 && (bonusCount + jackpotCount) >= preset.holdTriggerCount;
        // forge-lint: disable-next-line(unsafe-typecast)
        base.holdFillCount = uint8(bonusCount + jackpotCount);
    }

    function _evaluateWays(PresetConfig storage preset, uint256 stake, uint16[] memory grid, SpinResult storage result)
        internal
        returns (uint256 payout)
    {
        for (uint256 i = 0; i < preset.paytableSymbolIds.length; i++) {
            uint16 symbol = preset.paytableSymbolIds[i];
            uint8 matchesRequired = preset.paytableMatchCounts[i];
            uint256 multiplierBps = preset.paytableMultiplierBps[i];
            (uint8 matches, uint16 waysCount) = _countWays(preset, grid, symbol);
            if (matches >= matchesRequired && waysCount > 0) {
                uint256 wayPayout = (stake * multiplierBps * uint256(waysCount)) / 10_000;
                payout += wayPayout;
                result.wayWinSymbolIds.push(symbol);
                result.wayWinMatchCounts.push(matches);
                result.wayWinWayCounts.push(waysCount);
                result.wayWinPayouts.push(wayPayout);
            }
        }
    }

    function _countWays(PresetConfig storage preset, uint16[] memory grid, uint16 symbol)
        internal
        view
        returns (uint8 matches, uint16 waysCount)
    {
        waysCount = 1;
        for (uint256 reel = 0; reel < preset.reelCount; reel++) {
            uint16 reelMatches;
            for (uint256 row = 0; row < preset.rowCount; row++) {
                uint16 current = grid[(reel * preset.rowCount) + row];
                if (current == symbol || (preset.wildSymbolId != 0 && current == preset.wildSymbolId)) {
                    reelMatches += 1;
                }
            }
            if (reelMatches == 0) {
                break;
            }
            matches += 1;
            waysCount *= reelMatches;
        }
        if (matches == 0) {
            waysCount = 0;
        }
    }

    function _resolveFreeSpins(PresetConfig storage preset, uint256 stake, uint256 seed, uint8 startingEvents)
        internal
        view
        returns (uint8 awardedSpins, uint256 payout, uint8 retriggersUsed, uint8 eventCount)
    {
        awardedSpins = _lookupFreeSpinCount(preset, preset.freeSpinTriggerCount);
        uint8 spinsRemaining = awardedSpins;
        uint8 spinIndex;
        while (spinsRemaining > 0) {
            require(startingEvents + eventCount < preset.maxTotalEvents, "SlotMachine: event cap");
            uint16[] memory grid = _generateGrid(preset, seed, 10_000 + spinIndex);
            uint256 spinPayout = _evaluateWaysView(preset, stake, grid);
            payout += (spinPayout * preset.freeSpinMultiplierBps) / 10_000;
            eventCount += 1;

            uint256 scatterCount = _countSymbol(grid, preset.scatterSymbolId);
            if (scatterCount >= preset.freeSpinTriggerCount && retriggersUsed < preset.maxRetriggers && awardedSpins < preset.maxFreeSpins) {
                // forge-lint: disable-next-line(unsafe-typecast)
                uint8 extra = _lookupFreeSpinCount(preset, uint8(scatterCount));
                if (awardedSpins + extra > preset.maxFreeSpins) {
                    extra = preset.maxFreeSpins - awardedSpins;
                }
                awardedSpins += extra;
                spinsRemaining += extra;
                retriggersUsed += 1;
            }

            spinsRemaining -= 1;
            spinIndex += 1;
        }
    }

    function _resolvePickBonus(PresetConfig storage preset, uint256 stake, uint256 seed, uint8 startingEvents)
        internal
        view
        returns (uint256 payout, uint8 reveals)
    {
        reveals = preset.maxPickReveals;
        require(startingEvents + reveals <= preset.maxTotalEvents, "SlotMachine: event cap");
        for (uint256 i = 0; i < reveals; i++) {
            uint256 random = uint256(keccak256(abi.encode(seed, 20_000 + i)));
            uint256 idx = random % preset.pickAwardMultiplierBps.length;
            payout += (stake * preset.pickAwardMultiplierBps[idx]) / 10_000;
        }
    }

    function _resolveHoldAndSpin(
        PresetConfig storage preset,
        uint256 stake,
        uint256 seed,
        uint8 startingEvents,
        uint8 initialFilled
    ) internal view returns (uint256 payout, uint8 filled, uint8 respinsUsed, uint8 jackpotTierHit, uint256 jackpotPayout, uint8 eventCount) {
        HoldSpinState memory state;
        state.spinsRemaining = preset.initialRespins;
        state.filled = initialFilled > preset.holdBoardSize ? preset.holdBoardSize : initialFilled;

        while (state.spinsRemaining > 0 && state.filled < preset.holdBoardSize) {
            require(startingEvents + eventCount < preset.maxTotalEvents, "SlotMachine: event cap");
            uint256 random = uint256(keccak256(abi.encode(seed, 30_000 + state.respinsUsed)));
            uint256 remainingSlots = preset.holdBoardSize - state.filled;
            uint256 newHits = random % (remainingSlots + 1);
            if (newHits > 0) {
                state.spinsRemaining = preset.initialRespins;
            } else {
                state.spinsRemaining -= 1;
            }
            if (newHits > remainingSlots) {
                newHits = remainingSlots;
            }

            _accumulateHoldHits(state, preset, stake, seed, newHits);
            // forge-lint: disable-next-line(unsafe-typecast)
            state.filled += uint8(newHits);
            state.respinsUsed += 1;
            eventCount += 1;
            if (state.respinsUsed >= preset.maxRespins) {
                break;
            }
        }

        payout = state.payout;
        filled = state.filled;
        respinsUsed = state.respinsUsed;
        jackpotTierHit = state.jackpotTierHit;
        jackpotPayout = state.jackpotPayout;
    }

    function _accumulateHoldHits(
        HoldSpinState memory state,
        PresetConfig storage preset,
        uint256 stake,
        uint256 seed,
        uint256 newHits
    ) internal view {
        for (uint256 i = 0; i < newHits; i++) {
            (uint256 valuePayout, uint8 tierHit, uint256 tierPayout) =
                _drawHoldValue(preset, stake, uint256(keccak256(abi.encode(seed, 31_000 + state.respinsUsed, i))));
            state.payout += valuePayout;
            if (tierHit != 0) {
                state.jackpotTierHit = tierHit;
                state.jackpotPayout += tierPayout;
            }
        }
    }

    function _drawHoldValue(PresetConfig storage preset, uint256 stake, uint256 random)
        internal
        view
        returns (uint256 payout, uint8 jackpotTierHit, uint256 jackpotPayout)
    {
        uint256 jackpotWeight;
        for (uint256 i = 0; i < preset.jackpotTierWeights.length; i++) {
            jackpotWeight += preset.jackpotTierWeights[i];
        }
        uint256 valueWeight = preset.holdValueMultiplierBps.length * 10_000;
        uint256 draw = random % (valueWeight + jackpotWeight);

        if (draw < valueWeight) {
            uint256 idx = (draw / 10_000) % preset.holdValueMultiplierBps.length;
            payout = (stake * preset.holdValueMultiplierBps[idx]) / 10_000;
            return (payout, 0, 0);
        }

        uint256 running = valueWeight;
        for (uint256 i = 0; i < preset.jackpotTierWeights.length; i++) {
            running += preset.jackpotTierWeights[i];
            if (draw < running) {
                jackpotTierHit = preset.jackpotTierIds[i];
                jackpotPayout = (stake * preset.jackpotAwardMultiplierBps[i]) / 10_000;
                payout = jackpotPayout;
                return (payout, jackpotTierHit, jackpotPayout);
            }
        }
    }

    function _lookupFreeSpinCount(PresetConfig storage preset, uint8 count) internal view returns (uint8) {
        uint256 idx = count - preset.freeSpinTriggerCount;
        if (idx >= preset.freeSpinAwardCounts.length) {
            return preset.freeSpinAwardCounts[preset.freeSpinAwardCounts.length - 1];
        }
        return preset.freeSpinAwardCounts[idx];
    }

    function _evaluateWaysView(PresetConfig storage preset, uint256 stake, uint16[] memory grid) internal view returns (uint256 payout) {
        for (uint256 i = 0; i < preset.paytableSymbolIds.length; i++) {
            (uint8 matches, uint16 waysCount) = _countWays(preset, grid, preset.paytableSymbolIds[i]);
            if (matches >= preset.paytableMatchCounts[i] && waysCount > 0) {
                payout += (stake * preset.paytableMultiplierBps[i] * uint256(waysCount)) / 10_000;
            }
        }
    }

    function _countSymbol(uint16[] memory grid, uint16 symbol) internal pure returns (uint256 count) {
        if (symbol == 0) {
            return 0;
        }
        for (uint256 i = 0; i < grid.length; i++) {
            if (grid[i] == symbol) {
                count += 1;
            }
        }
    }

    function _replaceUint16Array(uint16[] storage target, uint16[] memory source) internal {
        while (target.length > 0) {
            target.pop();
        }
        for (uint256 i = 0; i < source.length; i++) {
            target.push(source[i]);
        }
    }

    function _pushUint16Array(uint16[] storage target, uint16[] calldata source) internal {
        for (uint256 i = 0; i < source.length; i++) {
            target.push(source[i]);
        }
    }

    function _pushUint8Array(uint8[] storage target, uint8[] calldata source) internal {
        for (uint256 i = 0; i < source.length; i++) {
            target.push(source[i]);
        }
    }

    function _pushUint32Array(uint32[] storage target, uint32[] calldata source) internal {
        for (uint256 i = 0; i < source.length; i++) {
            target.push(source[i]);
        }
    }

    function _getNextRequestId() internal view returns (uint256) {
        (bool success, bytes memory data) = VRF_COORDINATOR.staticcall(abi.encodeWithSignature("requestCounter()"));
        require(success, "SlotMachine: counter failed");
        return abi.decode(data, (uint256)) + 1;
    }

    function _requestRandomness() internal returns (uint256) {
        (bool success, bytes memory data) = VRF_COORDINATOR.call(
            abi.encodeWithSignature(
                "requestRandomWords(bytes32,uint64,uint16,uint32,uint32)",
                bytes32(0),
                uint64(0),
                uint16(3),
                uint32(2_500_000),
                uint32(1)
            )
        );
        require(success, "SlotMachine: vrf failed");
        return abi.decode(data, (uint256));
    }
}
