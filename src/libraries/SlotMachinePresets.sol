// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SlotMachineEngine} from "../engines/SlotMachineEngine.sol";

library SlotMachinePresets {
    function basePreset(uint8 volatility) internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config.volatilityTier = volatility;
        config.configHash = keccak256("base");
        config.reelCount = 5;
        config.rowCount = 3;
        config.waysMode = 1;
        config.minStake = 1 ether;
        config.maxStake = 1_000 ether;
        config.maxPayoutMultiplierBps = 10_000_000;
        config.symbolIds = new uint16[](4);
        config.symbolIds[0] = 1;
        config.symbolIds[1] = 2;
        config.symbolIds[2] = 3;
        config.symbolIds[3] = 4;
        config.wildSymbolId = 0;
        config.scatterSymbolId = 2;
        config.bonusSymbolId = 3;
        config.jackpotSymbolId = 4;
        config.reelWeightOffsets = new uint16[](6);
        config.reelSymbolIds = new uint16[](5);
        config.reelSymbolWeights = new uint16[](5);
        for (uint256 i = 0; i < 5; i++) {
            // casting to uint16 is safe because the canonical preset uses five reels.
            // forge-lint: disable-next-line(unsafe-typecast)
            config.reelWeightOffsets[i] = uint16(i);
            config.reelSymbolIds[i] = 1;
            config.reelSymbolWeights[i] = 100;
        }
        config.reelWeightOffsets[5] = 5;
        config.paytableSymbolIds = new uint16[](1);
        config.paytableSymbolIds[0] = 1;
        config.paytableMatchCounts = new uint8[](1);
        config.paytableMatchCounts[0] = 3;
        config.paytableMultiplierBps = new uint32[](1);
        config.paytableMultiplierBps[0] = 1_000;
        config.freeSpinTriggerCount = 3;
        config.freeSpinAwardCounts = new uint8[](2);
        config.freeSpinAwardCounts[0] = 3;
        config.freeSpinAwardCounts[1] = 5;
        config.maxFreeSpins = 8;
        config.maxRetriggers = 2;
        config.freeSpinMultiplierBps = 10_000;
        config.pickTriggerCount = 20;
        config.maxPickReveals = 3;
        config.pickAwardMultiplierBps = new uint32[](2);
        config.pickAwardMultiplierBps[0] = 500;
        config.pickAwardMultiplierBps[1] = 1_500;
        config.holdTriggerCount = 20;
        config.holdBoardSize = 20;
        config.initialRespins = 3;
        config.maxRespins = 6;
        config.holdValueMultiplierBps = new uint32[](1);
        config.holdValueMultiplierBps[0] = 500;
        config.jackpotTierIds = new uint8[](1);
        config.jackpotTierIds[0] = 1;
        config.jackpotAwardMultiplierBps = new uint32[](1);
        config.jackpotAwardMultiplierBps[0] = 5_000;
        config.jackpotTierWeights = new uint16[](1);
        config.jackpotTierWeights[0] = 1;
        config.maxTotalEvents = 24;
    }

    function freeSpinPreset(uint8 volatility) internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config = basePreset(volatility);
        config.configHash = keccak256("free");
        for (uint256 i = 0; i < config.reelSymbolIds.length; i++) {
            config.reelSymbolIds[i] = 2;
        }
        config.paytableSymbolIds[0] = 2;
        config.paytableMatchCounts[0] = 5;
        config.paytableMultiplierBps[0] = 2_000;
        config.freeSpinMultiplierBps = 15_000;
        config.maxFreeSpins = 6;
        config.maxRetriggers = 1;
        config.maxTotalEvents = 16;
    }

    function pickPreset(uint8 volatility) internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config = basePreset(volatility);
        config.configHash = keccak256("pick");
        for (uint256 i = 0; i < config.reelSymbolIds.length; i++) {
            config.reelSymbolIds[i] = 3;
        }
        config.pickTriggerCount = 1;
        config.maxPickReveals = 4;
        config.pickAwardMultiplierBps = new uint32[](2);
        config.pickAwardMultiplierBps[0] = 1_000;
        config.pickAwardMultiplierBps[1] = 2_000;
        config.holdTriggerCount = 20;
        config.maxTotalEvents = 16;
    }

    function holdPreset(uint8 volatility) internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config = basePreset(volatility);
        config.configHash = keccak256("hold");
        for (uint256 i = 0; i < config.reelSymbolIds.length; i++) {
            config.reelSymbolIds[i] = 3;
        }
        config.pickTriggerCount = 20;
        config.holdTriggerCount = 1;
        config.holdBoardSize = 20;
        config.initialRespins = 3;
        config.maxRespins = 5;
        config.holdValueMultiplierBps = new uint32[](1);
        config.holdValueMultiplierBps[0] = 2_500;
        config.jackpotTierIds = new uint8[](1);
        config.jackpotTierIds[0] = 1;
        config.jackpotAwardMultiplierBps = new uint32[](1);
        config.jackpotAwardMultiplierBps[0] = 7_500;
        config.jackpotTierWeights = new uint16[](1);
        config.jackpotTierWeights[0] = 60_000;
        config.maxTotalEvents = 20;
    }
}
