// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BlackjackController} from "../controllers/BlackjackController.sol";
import {BlackjackEngine} from "../engines/BlackjackEngine.sol";
import {BlackjackVerifierBundle} from "../verifiers/BlackjackVerifierBundle.sol";
import {BlackjackActionResolveVerifier} from "../verifiers/generated/BlackjackActionResolveVerifier.sol";
import {BlackjackInitialDealVerifier} from "../verifiers/generated/BlackjackInitialDealVerifier.sol";
import {BlackjackPeekVerifier} from "../verifiers/generated/BlackjackPeekVerifier.sol";
import {BlackjackShowdownVerifier} from "../verifiers/generated/BlackjackShowdownVerifier.sol";
import {IBlackjackModuleDeployer} from "./IModuleDeployers.sol";

contract BlackjackModuleDeployer is IBlackjackModuleDeployer {
    function deployBlackjackModule(
        address catalogAddress,
        address settlementAddress,
        address coordinator,
        uint256 defaultActionWindow,
        address admin
    ) external returns (address controller, address engine, address verifier, bytes32 engineType) {
        BlackjackInitialDealVerifier initialDealVerifier = new BlackjackInitialDealVerifier();
        BlackjackPeekVerifier peekVerifier = new BlackjackPeekVerifier();
        BlackjackActionResolveVerifier actionResolveVerifier = new BlackjackActionResolveVerifier();
        BlackjackShowdownVerifier showdownVerifier = new BlackjackShowdownVerifier();
        BlackjackVerifierBundle blackjackVerifierBundle = new BlackjackVerifierBundle(
            admin,
            address(initialDealVerifier),
            address(peekVerifier),
            address(actionResolveVerifier),
            address(showdownVerifier)
        );

        BlackjackEngine blackjackEngine =
            new BlackjackEngine(catalogAddress, address(blackjackVerifierBundle), coordinator, defaultActionWindow);
        BlackjackController blackjackController =
            new BlackjackController(settlementAddress, catalogAddress, address(blackjackEngine));

        controller = address(blackjackController);
        engine = address(blackjackEngine);
        verifier = address(blackjackVerifierBundle);
        engineType = blackjackEngine.engineType();
    }
}
