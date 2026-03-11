// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { GameCatalog } from "./GameCatalog.sol";
import { ProtocolSettlement } from "./ProtocolSettlement.sol";
import { BlackjackController } from "./controllers/BlackjackController.sol";
import { NumberPickerAdapter } from "./controllers/NumberPickerAdapter.sol";
import { PvPController } from "./controllers/PvPController.sol";
import { TournamentController } from "./controllers/TournamentController.sol";
import { NumberPickerEngine } from "./engines/NumberPickerEngine.sol";
import { SingleDeckBlackjackEngine } from "./engines/SingleDeckBlackjackEngine.sol";
import { SingleDraw2To7Engine } from "./engines/SingleDraw2To7Engine.sol";
import { BlackjackVerifierBundle } from "./verifiers/BlackjackVerifierBundle.sol";
import { LaunchVerificationKeyHashes } from "./verifiers/LaunchVerificationKeyHashes.sol";
import { PokerVerifierBundle } from "./verifiers/PokerVerifierBundle.sol";
import { BlackjackActionResolveVerifier } from "./verifiers/generated/BlackjackActionResolveVerifier.sol";
import { BlackjackInitialDealVerifier } from "./verifiers/generated/BlackjackInitialDealVerifier.sol";
import { BlackjackShowdownVerifier } from "./verifiers/generated/BlackjackShowdownVerifier.sol";
import { PokerDrawResolveVerifier } from "./verifiers/generated/PokerDrawResolveVerifier.sol";
import { PokerInitialDealVerifier } from "./verifiers/generated/PokerInitialDealVerifier.sol";
import { PokerShowdownVerifier } from "./verifiers/generated/PokerShowdownVerifier.sol";

contract GameDeploymentFactory is AccessControl {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    enum SoloFamily {
        NumberPicker,
        Blackjack
    }

    enum MatchFamily {
        PokerSingleDraw2To7
    }

    struct NumberPickerDeployment {
        address vrfCoordinator;
        bytes32 configHash;
        uint16 developerRewardBps;
    }

    struct BlackjackDeployment {
        address coordinator;
        uint256 defaultActionWindow;
        bytes32 configHash;
        uint16 developerRewardBps;
    }

    struct PokerDeployment {
        address coordinator;
        uint256 smallBlind;
        uint256 bigBlind;
        uint256 blindEscalationInterval;
        uint256 actionWindow;
        bytes32 configHash;
        uint16 developerRewardBps;
    }

    GameCatalog internal immutable CATALOG;
    ProtocolSettlement internal immutable SETTLEMENT;

    event ModuleDeployed(
        uint256 indexed moduleId,
        GameCatalog.GameMode indexed mode,
        uint8 indexed family,
        address controller,
        address engine,
        address verifier,
        bytes32 configHash
    );

    constructor(address admin, address catalogAddress, address settlementAddress) {
        CATALOG = GameCatalog(catalogAddress);
        SETTLEMENT = ProtocolSettlement(settlementAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEPLOYER_ROLE, admin);
    }

    function catalog() public view returns (GameCatalog) {
        return CATALOG;
    }

    function settlement() public view returns (ProtocolSettlement) {
        return SETTLEMENT;
    }

    function deploySoloModule(uint8 family, bytes calldata deploymentParams)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (uint256 moduleId, address controller, address engine, address verifier)
    {
        if (family == uint8(SoloFamily.NumberPicker)) {
            NumberPickerDeployment memory params = abi.decode(deploymentParams, (NumberPickerDeployment));
            NumberPickerEngine numberPickerEngine = new NumberPickerEngine(address(CATALOG), params.vrfCoordinator);
            NumberPickerAdapter numberPickerAdapter =
                new NumberPickerAdapter(address(SETTLEMENT), address(CATALOG), address(numberPickerEngine));

            controller = address(numberPickerAdapter);
            engine = address(numberPickerEngine);
            verifier = address(0);

            moduleId = CATALOG.registerModule(
                GameCatalog.Module({
                    mode: GameCatalog.GameMode.Solo,
                    controller: controller,
                    engine: engine,
                    engineType: numberPickerEngine.engineType(),
                    verifier: verifier,
                    configHash: params.configHash,
                    developerRewardBps: params.developerRewardBps,
                    status: GameCatalog.ModuleStatus.LIVE
                })
            );
        } else if (family == uint8(SoloFamily.Blackjack)) {
            BlackjackDeployment memory params = abi.decode(deploymentParams, (BlackjackDeployment));

            BlackjackInitialDealVerifier initialDealVerifier = new BlackjackInitialDealVerifier();
            BlackjackActionResolveVerifier actionResolveVerifier = new BlackjackActionResolveVerifier();
            BlackjackShowdownVerifier showdownVerifier = new BlackjackShowdownVerifier();
            BlackjackVerifierBundle blackjackVerifierBundle = new BlackjackVerifierBundle(
                msg.sender,
                LaunchVerificationKeyHashes.BLACKJACK_INITIAL_DEAL_VK_HASH,
                LaunchVerificationKeyHashes.BLACKJACK_ACTION_VK_HASH,
                LaunchVerificationKeyHashes.BLACKJACK_SHOWDOWN_VK_HASH,
                address(initialDealVerifier),
                address(actionResolveVerifier),
                address(showdownVerifier)
            );

            SingleDeckBlackjackEngine blackjackEngine = new SingleDeckBlackjackEngine(
                address(CATALOG), address(blackjackVerifierBundle), params.coordinator, params.defaultActionWindow
            );
            BlackjackController blackjackController =
                new BlackjackController(address(SETTLEMENT), address(CATALOG), address(blackjackEngine));

            controller = address(blackjackController);
            engine = address(blackjackEngine);
            verifier = address(blackjackVerifierBundle);

            moduleId = CATALOG.registerModule(
                GameCatalog.Module({
                    mode: GameCatalog.GameMode.Solo,
                    controller: controller,
                    engine: engine,
                    engineType: blackjackEngine.engineType(),
                    verifier: verifier,
                    configHash: params.configHash,
                    developerRewardBps: params.developerRewardBps,
                    status: GameCatalog.ModuleStatus.LIVE
                })
            );
        } else {
            revert("Factory: unsupported solo family");
        }

        emit ModuleDeployed(
            moduleId,
            GameCatalog.GameMode.Solo,
            family,
            controller,
            engine,
            verifier,
            CATALOG.getModule(moduleId).configHash
        );
    }

    function deployPvPModule(uint8 family, bytes calldata deploymentParams)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (uint256 moduleId, address controller, address engine, address verifier)
    {
        require(family == uint8(MatchFamily.PokerSingleDraw2To7), "Factory: unsupported pvp family");
        PokerDeployment memory params = abi.decode(deploymentParams, (PokerDeployment));

        (engine, verifier) = _deployPokerEngine(params);
        controller = address(new PvPController(msg.sender, address(SETTLEMENT), address(CATALOG), engine));

        moduleId = CATALOG.registerModule(
            GameCatalog.Module({
                mode: GameCatalog.GameMode.PvP,
                controller: controller,
                engine: engine,
                engineType: SingleDraw2To7Engine(engine).engineType(),
                verifier: verifier,
                configHash: params.configHash,
                developerRewardBps: params.developerRewardBps,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );

        emit ModuleDeployed(moduleId, GameCatalog.GameMode.PvP, family, controller, engine, verifier, params.configHash);
    }

    function deployTournamentModule(uint8 family, bytes calldata deploymentParams)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (uint256 moduleId, address controller, address engine, address verifier)
    {
        require(family == uint8(MatchFamily.PokerSingleDraw2To7), "Factory: unsupported tournament family");
        PokerDeployment memory params = abi.decode(deploymentParams, (PokerDeployment));

        (engine, verifier) = _deployPokerEngine(params);
        controller = address(new TournamentController(msg.sender, address(SETTLEMENT), address(CATALOG), engine));

        moduleId = CATALOG.registerModule(
            GameCatalog.Module({
                mode: GameCatalog.GameMode.Tournament,
                controller: controller,
                engine: engine,
                engineType: SingleDraw2To7Engine(engine).engineType(),
                verifier: verifier,
                configHash: params.configHash,
                developerRewardBps: params.developerRewardBps,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );

        emit ModuleDeployed(
            moduleId, GameCatalog.GameMode.Tournament, family, controller, engine, verifier, params.configHash
        );
    }

    function _deployPokerEngine(PokerDeployment memory params) internal returns (address engine, address verifier) {
        PokerInitialDealVerifier initialDealVerifier = new PokerInitialDealVerifier();
        PokerDrawResolveVerifier drawResolveVerifier = new PokerDrawResolveVerifier();
        PokerShowdownVerifier showdownVerifier = new PokerShowdownVerifier();
        PokerVerifierBundle pokerVerifierBundle = new PokerVerifierBundle(
            msg.sender,
            LaunchVerificationKeyHashes.POKER_INITIAL_DEAL_VK_HASH,
            LaunchVerificationKeyHashes.POKER_DRAW_VK_HASH,
            LaunchVerificationKeyHashes.POKER_SHOWDOWN_VK_HASH,
            address(initialDealVerifier),
            address(drawResolveVerifier),
            address(showdownVerifier)
        );

        SingleDraw2To7Engine pokerEngine = new SingleDraw2To7Engine(
            address(CATALOG),
            params.smallBlind,
            params.bigBlind,
            params.blindEscalationInterval,
            params.actionWindow,
            address(pokerVerifierBundle),
            params.coordinator
        );

        return (address(pokerEngine), address(pokerVerifierBundle));
    }
}
