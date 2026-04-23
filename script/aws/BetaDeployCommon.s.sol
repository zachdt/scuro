// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

abstract contract BetaDeployCommon is Script {
    uint256 internal constant DEFAULT_PLAYER1_PRIVATE_KEY =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 internal constant DEFAULT_PLAYER2_PRIVATE_KEY =
        0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    address internal constant SOLO_DEVELOPER = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    uint256 internal constant PLAYER_FUNDS = 10_000 ether;
    uint256 internal constant DEVELOPER_FUNDS = 1_000 ether;

    function adminPrivateKey() internal view returns (uint256) {
        return vm.envUint("PRIVATE_KEY");
    }

    function adminAddress() internal view returns (address) {
        return vm.addr(adminPrivateKey());
    }

    function player1PrivateKey() internal view returns (uint256) {
        return vm.envOr("PLAYER1_PRIVATE_KEY", DEFAULT_PLAYER1_PRIVATE_KEY);
    }

    function player2PrivateKey() internal view returns (uint256) {
        return vm.envOr("PLAYER2_PRIVATE_KEY", DEFAULT_PLAYER2_PRIVATE_KEY);
    }

    function player1Address() internal view returns (address) {
        return vm.addr(player1PrivateKey());
    }

    function player2Address() internal view returns (address) {
        return vm.addr(player2PrivateKey());
    }

    function envAddress(string memory key) internal view returns (address) {
        return vm.envAddress(key);
    }

    function envUint(string memory key) internal view returns (uint256) {
        return vm.envUint(key);
    }

    function logStage(string memory stage) internal view {
        console.log("Stage", stage);
    }

    function logStageAction(string memory action) internal view {
        console.log("StageAction", action);
    }

    function logAddress(string memory label, address value) internal view {
        console.log(label, value);
    }

    function logUint(string memory label, uint256 value) internal view {
        console.log(label, value);
    }
}
