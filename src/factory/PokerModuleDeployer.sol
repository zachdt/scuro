// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {PvPController} from "../controllers/PvPController.sol";
import {TournamentController} from "../controllers/TournamentController.sol";
import {SingleDraw2To7Engine} from "../engines/SingleDraw2To7Engine.sol";
import {PokerVerifierBundle} from "../verifiers/PokerVerifierBundle.sol";
import {PokerDrawResolveVerifier} from "../verifiers/generated/PokerDrawResolveVerifier.sol";
import {PokerInitialDealVerifier} from "../verifiers/generated/PokerInitialDealVerifier.sol";
import {PokerShowdownVerifier} from "../verifiers/generated/PokerShowdownVerifier.sol";
import {IPokerModuleDeployer} from "./IModuleDeployers.sol";

contract PokerModuleDeployer is IPokerModuleDeployer {
    function deployPvPModule(
        address catalogAddress,
        address settlementAddress,
        address coordinator,
        uint256 smallBlind,
        uint256 bigBlind,
        uint256 blindEscalationInterval,
        uint256 actionWindow,
        address admin
    ) external returns (address controller, address engine, address verifier, bytes32 engineType) {
        (SingleDraw2To7Engine pokerEngine, PokerVerifierBundle verifierBundle) = _deployPokerEngine(
            catalogAddress,
            coordinator,
            smallBlind,
            bigBlind,
            blindEscalationInterval,
            actionWindow,
            admin
        );

        PvPController pvpController = new PvPController(admin, settlementAddress, catalogAddress, address(pokerEngine));

        controller = address(pvpController);
        engine = address(pokerEngine);
        verifier = address(verifierBundle);
        engineType = pokerEngine.engineType();
    }

    function deployTournamentModule(
        address catalogAddress,
        address settlementAddress,
        address coordinator,
        uint256 smallBlind,
        uint256 bigBlind,
        uint256 blindEscalationInterval,
        uint256 actionWindow,
        address admin
    ) external returns (address controller, address engine, address verifier, bytes32 engineType) {
        (SingleDraw2To7Engine pokerEngine, PokerVerifierBundle verifierBundle) = _deployPokerEngine(
            catalogAddress,
            coordinator,
            smallBlind,
            bigBlind,
            blindEscalationInterval,
            actionWindow,
            admin
        );

        TournamentController tournamentController =
            new TournamentController(admin, settlementAddress, catalogAddress, address(pokerEngine));

        controller = address(tournamentController);
        engine = address(pokerEngine);
        verifier = address(verifierBundle);
        engineType = pokerEngine.engineType();
    }

    function _deployPokerEngine(
        address catalogAddress,
        address coordinator,
        uint256 smallBlind,
        uint256 bigBlind,
        uint256 blindEscalationInterval,
        uint256 actionWindow,
        address admin
    ) internal returns (SingleDraw2To7Engine pokerEngine, PokerVerifierBundle verifierBundle) {
        PokerInitialDealVerifier initialDealVerifier = new PokerInitialDealVerifier();
        PokerDrawResolveVerifier drawResolveVerifier = new PokerDrawResolveVerifier();
        PokerShowdownVerifier showdownVerifier = new PokerShowdownVerifier();
        verifierBundle = new PokerVerifierBundle(
            admin, address(initialDealVerifier), address(drawResolveVerifier), address(showdownVerifier)
        );

        pokerEngine = new SingleDraw2To7Engine(
            catalogAddress,
            smallBlind,
            bigBlind,
            blindEscalationInterval,
            actionWindow,
            address(verifierBundle),
            coordinator
        );
    }
}
