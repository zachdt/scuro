// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

abstract contract BetaDeployCommon is Script {
    address internal constant PLAYER1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant PLAYER2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal constant SOLO_DEVELOPER = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address internal constant POKER_DEVELOPER = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
    uint256 internal constant PLAYER_FUNDS = 10_000 ether;
    uint256 internal constant DEVELOPER_FUNDS = 1_000 ether;

    function adminPrivateKey() internal view returns (uint256) {
        return vm.envUint("PRIVATE_KEY");
    }

    function adminAddress() internal view returns (address) {
        return vm.addr(adminPrivateKey());
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
