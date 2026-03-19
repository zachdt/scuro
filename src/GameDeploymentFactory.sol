// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {GameCatalog} from "./GameCatalog.sol";
import {ProtocolSettlement} from "./ProtocolSettlement.sol";
import {CheminDeFerController} from "./controllers/CheminDeFerController.sol";
import {BlackjackController} from "./controllers/BlackjackController.sol";
import {NumberPickerAdapter} from "./controllers/NumberPickerAdapter.sol";
import {PvPController} from "./controllers/PvPController.sol";
import {SlotMachineController} from "./controllers/SlotMachineController.sol";
import {SuperBaccaratController} from "./controllers/SuperBaccaratController.sol";
import {TournamentController} from "./controllers/TournamentController.sol";
import {CheminDeFerEngine} from "./engines/CheminDeFerEngine.sol";
import {NumberPickerEngine} from "./engines/NumberPickerEngine.sol";
import {SingleDeckBlackjackEngine} from "./engines/SingleDeckBlackjackEngine.sol";
import {SingleDraw2To7Engine} from "./engines/SingleDraw2To7Engine.sol";
import {SlotMachineEngine} from "./engines/SlotMachineEngine.sol";
import {SuperBaccaratEngine} from "./engines/SuperBaccaratEngine.sol";
import {IScuroGameEngine} from "./interfaces/IScuroGameEngine.sol";
import {BlackjackVerifierBundle} from "./verifiers/BlackjackVerifierBundle.sol";
import {PokerVerifierBundle} from "./verifiers/PokerVerifierBundle.sol";
import {BlackjackActionResolveVerifier} from "./verifiers/generated/BlackjackActionResolveVerifier.sol";
import {BlackjackInitialDealVerifier} from "./verifiers/generated/BlackjackInitialDealVerifier.sol";
import {BlackjackShowdownVerifier} from "./verifiers/generated/BlackjackShowdownVerifier.sol";
import {PokerDrawResolveVerifier} from "./verifiers/generated/PokerDrawResolveVerifier.sol";
import {PokerInitialDealVerifier} from "./verifiers/generated/PokerInitialDealVerifier.sol";
import {PokerShowdownVerifier} from "./verifiers/generated/PokerShowdownVerifier.sol";

/// @title Scuro game deployment factory
/// @notice Deploys shipped controller/engine/verifier bundles and registers them in the catalog.
contract GameDeploymentFactory is AccessControl {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    /// @notice Supported solo module families.
    enum SoloFamily {
        NumberPicker,
        Blackjack,
        SuperBaccarat,
        SlotMachine
    }

    /// @notice Supported competitive module families.
    enum MatchFamily {
        PokerSingleDraw2To7,
        CheminDeFerBaccarat
    }

    /// @notice ABI shape for deploying a NumberPicker module.
    struct NumberPickerDeployment {
        address vrfCoordinator;
        bytes32 configHash;
        uint16 developerRewardBps;
    }

    /// @notice ABI shape for deploying a blackjack module.
    struct BlackjackDeployment {
        address coordinator;
        uint256 defaultActionWindow;
        bytes32 configHash;
        uint16 developerRewardBps;
    }

    /// @notice ABI shape for deploying a solo baccarat module.
    struct BaccaratDeployment {
        address vrfCoordinator;
        bytes32 configHash;
        uint16 developerRewardBps;
    }

    /// @notice ABI shape for deploying a slot machine module.
    struct SlotDeployment {
        address vrfCoordinator;
        bytes32 configHash;
        uint16 developerRewardBps;
    }

    /// @notice ABI shape for deploying poker modules.
    struct PokerDeployment {
        address coordinator;
        uint256 smallBlind;
        uint256 bigBlind;
        uint256 blindEscalationInterval;
        uint256 actionWindow;
        bytes32 configHash;
        uint16 developerRewardBps;
    }

    /// @notice ABI shape for deploying chemin de fer modules.
    struct CheminDeFerDeployment {
        address vrfCoordinator;
        uint256 joinWindow;
        bytes32 configHash;
        uint16 developerRewardBps;
    }

    GameCatalog internal immutable CATALOG;
    ProtocolSettlement internal immutable SETTLEMENT;

    /// @notice Emitted when the factory deploys a new module bundle.
    event ModuleDeployed(
        uint256 indexed moduleId,
        GameCatalog.GameMode indexed mode,
        uint8 indexed family,
        address controller,
        address engine,
        address verifier,
        bytes32 configHash
    );

    /// @notice Initializes the factory and grants deploy permissions to the admin.
    constructor(address admin, address catalogAddress, address settlementAddress) {
        CATALOG = GameCatalog(catalogAddress);
        SETTLEMENT = ProtocolSettlement(settlementAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEPLOYER_ROLE, admin);
    }

    /// @notice Returns the catalog used for module registration.
    function catalog() public view returns (GameCatalog) {
        return CATALOG;
    }

    /// @notice Returns the settlement contract injected into newly deployed controllers.
    function settlement() public view returns (ProtocolSettlement) {
        return SETTLEMENT;
    }

    /// @notice Deploys a supported solo-family module and registers it in the catalog.
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
                msg.sender, address(initialDealVerifier), address(actionResolveVerifier), address(showdownVerifier)
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
        } else if (family == uint8(SoloFamily.SuperBaccarat)) {
            BaccaratDeployment memory params = abi.decode(deploymentParams, (BaccaratDeployment));

            SuperBaccaratEngine baccaratEngine = new SuperBaccaratEngine(address(CATALOG), params.vrfCoordinator);
            SuperBaccaratController baccaratController =
                new SuperBaccaratController(address(SETTLEMENT), address(CATALOG), address(baccaratEngine));

            controller = address(baccaratController);
            engine = address(baccaratEngine);
            verifier = address(0);

            moduleId = CATALOG.registerModule(
                GameCatalog.Module({
                    mode: GameCatalog.GameMode.Solo,
                    controller: controller,
                    engine: engine,
                    engineType: baccaratEngine.engineType(),
                    verifier: verifier,
                    configHash: params.configHash,
                    developerRewardBps: params.developerRewardBps,
                    status: GameCatalog.ModuleStatus.LIVE
                })
            );
        } else if (family == uint8(SoloFamily.SlotMachine)) {
            SlotDeployment memory params = abi.decode(deploymentParams, (SlotDeployment));

            SlotMachineEngine slotEngine = new SlotMachineEngine(msg.sender, address(CATALOG), params.vrfCoordinator);
            SlotMachineController slotController =
                new SlotMachineController(address(SETTLEMENT), address(CATALOG), address(slotEngine));

            controller = address(slotController);
            engine = address(slotEngine);
            verifier = address(0);

            moduleId = CATALOG.registerModule(
                GameCatalog.Module({
                    mode: GameCatalog.GameMode.Solo,
                    controller: controller,
                    engine: engine,
                    engineType: slotEngine.engineType(),
                    verifier: verifier,
                    configHash: params.configHash,
                    developerRewardBps: params.developerRewardBps,
                    status: GameCatalog.ModuleStatus.LIVE
                })
            );
        } else {
            revert("Factory: unsupported solo family");
        }

        emit ModuleDeployed(moduleId, GameCatalog.GameMode.Solo, family, controller, engine, verifier, CATALOG.getModule(moduleId).configHash);
    }

    /// @notice Deploys a supported PvP-family module and registers it in the catalog.
    function deployPvPModule(uint8 family, bytes calldata deploymentParams)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (uint256 moduleId, address controller, address engine, address verifier)
    {
        if (family == uint8(MatchFamily.PokerSingleDraw2To7)) {
            PokerDeployment memory params = abi.decode(deploymentParams, (PokerDeployment));

            (engine, verifier) = _deployPokerEngine(params);
            controller = address(new PvPController(msg.sender, address(SETTLEMENT), address(CATALOG), engine));

            moduleId = CATALOG.registerModule(
                GameCatalog.Module({
                    mode: GameCatalog.GameMode.PvP,
                    controller: controller,
                    engine: engine,
                    engineType: IScuroGameEngine(engine).engineType(),
                    verifier: verifier,
                    configHash: params.configHash,
                    developerRewardBps: params.developerRewardBps,
                    status: GameCatalog.ModuleStatus.LIVE
                })
            );

            emit ModuleDeployed(moduleId, GameCatalog.GameMode.PvP, family, controller, engine, verifier, params.configHash);
        } else if (family == uint8(MatchFamily.CheminDeFerBaccarat)) {
            CheminDeFerDeployment memory params = abi.decode(deploymentParams, (CheminDeFerDeployment));

            CheminDeFerEngine baccaratEngine = new CheminDeFerEngine(address(CATALOG), params.vrfCoordinator);
            controller = address(
                new CheminDeFerController(address(SETTLEMENT), address(CATALOG), address(baccaratEngine), params.joinWindow)
            );
            engine = address(baccaratEngine);
            verifier = address(0);

            moduleId = CATALOG.registerModule(
                GameCatalog.Module({
                    mode: GameCatalog.GameMode.PvP,
                    controller: controller,
                    engine: engine,
                    engineType: baccaratEngine.engineType(),
                    verifier: verifier,
                    configHash: params.configHash,
                    developerRewardBps: params.developerRewardBps,
                    status: GameCatalog.ModuleStatus.LIVE
                })
            );

            emit ModuleDeployed(moduleId, GameCatalog.GameMode.PvP, family, controller, engine, verifier, params.configHash);
        } else {
            revert("Factory: unsupported pvp family");
        }
    }

    /// @notice Deploys a supported tournament-family module and registers it in the catalog.
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
                engineType: IScuroGameEngine(engine).engineType(),
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
            msg.sender, address(initialDealVerifier), address(drawResolveVerifier), address(showdownVerifier)
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
