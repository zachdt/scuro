// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { ScuroVerifierRegistry } from "../src/verifiers/ScuroVerifierRegistry.sol";

contract FinalizeVerifierRegistryHandoff is Script {
    address internal constant VERIFIER_REGISTRY = 0x0000000000000000000000000000000000000801;

    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        address timelock = vm.envAddress("TIMELOCK_CONTROLLER");
        address admin = vm.addr(adminKey);
        ScuroVerifierRegistry verifierRegistry = ScuroVerifierRegistry(VERIFIER_REGISTRY);

        require(address(verifierRegistry).code.length > 0, "FinalizeVerifierRegistryHandoff: missing registry");

        vm.startBroadcast(adminKey);
        if (!verifierRegistry.hasRole(verifierRegistry.DEFAULT_ADMIN_ROLE(), timelock)) {
            verifierRegistry.grantRole(verifierRegistry.DEFAULT_ADMIN_ROLE(), timelock);
        }
        if (!verifierRegistry.hasRole(verifierRegistry.REGISTRAR_ROLE(), timelock)) {
            verifierRegistry.grantRole(verifierRegistry.REGISTRAR_ROLE(), timelock);
        }
        if (verifierRegistry.hasRole(verifierRegistry.DEFAULT_ADMIN_ROLE(), admin)) {
            verifierRegistry.renounceRole(verifierRegistry.DEFAULT_ADMIN_ROLE(), admin);
        }
        if (verifierRegistry.hasRole(verifierRegistry.REGISTRAR_ROLE(), admin)) {
            verifierRegistry.renounceRole(verifierRegistry.REGISTRAR_ROLE(), admin);
        }
        vm.stopBroadcast();

        console.log("ScuroVerifierRegistry", address(verifierRegistry));
        console.log("TimelockController", timelock);
    }
}
