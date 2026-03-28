// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BlackjackController} from "../controllers/BlackjackController.sol";
import {SingleDeckBlackjackEngine} from "../engines/SingleDeckBlackjackEngine.sol";
import {BlackjackVerifierBundle} from "../verifiers/BlackjackVerifierBundle.sol";
import {BlackjackActionResolveVerifier} from "../verifiers/generated/BlackjackActionResolveVerifier.sol";
import {BlackjackInitialDealVerifier} from "../verifiers/generated/BlackjackInitialDealVerifier.sol";
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
        BlackjackActionResolveVerifier actionResolveVerifier = new BlackjackActionResolveVerifier();
        BlackjackShowdownVerifier showdownVerifier = new BlackjackShowdownVerifier();
        BlackjackVerifierBundle blackjackVerifierBundle = new BlackjackVerifierBundle(
            admin, address(initialDealVerifier), address(actionResolveVerifier), address(showdownVerifier)
        );

        SingleDeckBlackjackEngine blackjackEngine =
            new SingleDeckBlackjackEngine(catalogAddress, address(blackjackVerifierBundle), coordinator, defaultActionWindow);
        BlackjackController blackjackController =
            new BlackjackController(settlementAddress, catalogAddress, address(blackjackEngine));

        controller = address(blackjackController);
        engine = address(blackjackEngine);
        verifier = address(blackjackVerifierBundle);
        engineType = blackjackEngine.engineType();
    }
}
