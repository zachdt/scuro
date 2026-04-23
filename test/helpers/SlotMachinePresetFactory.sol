// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SlotMachineEngine} from "../../src/engines/SlotMachineEngine.sol";
import {SlotMachinePresets} from "../../src/libraries/SlotMachinePresets.sol";

library SlotMachinePresetFactory {
    function basePreset(uint8 volatility) internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config = SlotMachinePresets.basePreset(volatility);
    }

    function freeSpinPreset(uint8 volatility) internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config = SlotMachinePresets.freeSpinPreset(volatility);
    }

    function pickPreset(uint8 volatility) internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config = SlotMachinePresets.pickPreset(volatility);
    }

    function holdPreset(uint8 volatility) internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config = SlotMachinePresets.holdPreset(volatility);
    }

    function lowCapPreset() internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config = freeSpinPreset(1);
        config.configHash = keccak256("low-cap");
        config.maxPayoutMultiplierBps = 500;
    }

    function lowEventCapPreset() internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config = freeSpinPreset(1);
        config.configHash = keccak256("low-events");
        config.maxTotalEvents = 1;
    }
}
