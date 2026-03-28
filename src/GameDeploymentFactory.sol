// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {GameCatalog} from "./GameCatalog.sol";
import {ProtocolSettlement} from "./ProtocolSettlement.sol";
import {
    IBlackjackModuleDeployer,
    ICheminDeFerModuleDeployer,
    IPokerModuleDeployer,
    ISoloModuleDeployer
} from "./factory/IModuleDeployers.sol";

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
    ISoloModuleDeployer internal immutable SOLO_MODULE_DEPLOYER;
    IBlackjackModuleDeployer internal immutable BLACKJACK_MODULE_DEPLOYER;
    IPokerModuleDeployer internal immutable POKER_MODULE_DEPLOYER;
    ICheminDeFerModuleDeployer internal immutable CHEMIN_DE_FER_MODULE_DEPLOYER;

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
    constructor(
        address admin,
        address catalogAddress,
        address settlementAddress,
        address soloModuleDeployer,
        address blackjackModuleDeployer,
        address pokerModuleDeployer,
        address cheminDeFerModuleDeployer
    ) {
        CATALOG = GameCatalog(catalogAddress);
        SETTLEMENT = ProtocolSettlement(settlementAddress);
        SOLO_MODULE_DEPLOYER = ISoloModuleDeployer(soloModuleDeployer);
        BLACKJACK_MODULE_DEPLOYER = IBlackjackModuleDeployer(blackjackModuleDeployer);
        POKER_MODULE_DEPLOYER = IPokerModuleDeployer(pokerModuleDeployer);
        CHEMIN_DE_FER_MODULE_DEPLOYER = ICheminDeFerModuleDeployer(cheminDeFerModuleDeployer);
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
        bytes32 engineType;
        bytes32 configHash;
        uint16 developerRewardBps;

        if (family == uint8(SoloFamily.NumberPicker)) {
            NumberPickerDeployment memory params = abi.decode(deploymentParams, (NumberPickerDeployment));
            (controller, engine, verifier, engineType) = SOLO_MODULE_DEPLOYER.deployNumberPickerModule(
                address(CATALOG), address(SETTLEMENT), params.vrfCoordinator
            );
            configHash = params.configHash;
            developerRewardBps = params.developerRewardBps;
        } else if (family == uint8(SoloFamily.Blackjack)) {
            BlackjackDeployment memory params = abi.decode(deploymentParams, (BlackjackDeployment));
            (controller, engine, verifier, engineType) = BLACKJACK_MODULE_DEPLOYER.deployBlackjackModule(
                address(CATALOG), address(SETTLEMENT), params.coordinator, params.defaultActionWindow, msg.sender
            );
            configHash = params.configHash;
            developerRewardBps = params.developerRewardBps;
        } else if (family == uint8(SoloFamily.SuperBaccarat)) {
            BaccaratDeployment memory params = abi.decode(deploymentParams, (BaccaratDeployment));
            (controller, engine, verifier, engineType) = SOLO_MODULE_DEPLOYER.deploySuperBaccaratModule(
                address(CATALOG), address(SETTLEMENT), params.vrfCoordinator
            );
            configHash = params.configHash;
            developerRewardBps = params.developerRewardBps;
        } else if (family == uint8(SoloFamily.SlotMachine)) {
            SlotDeployment memory params = abi.decode(deploymentParams, (SlotDeployment));
            (controller, engine, verifier, engineType) = SOLO_MODULE_DEPLOYER.deploySlotMachineModule(
                address(CATALOG), address(SETTLEMENT), params.vrfCoordinator, msg.sender
            );
            configHash = params.configHash;
            developerRewardBps = params.developerRewardBps;
        } else {
            revert("Factory: unsupported solo family");
        }

        moduleId = _registerModule(
            GameCatalog.GameMode.Solo, controller, engine, engineType, verifier, configHash, developerRewardBps
        );
        emit ModuleDeployed(moduleId, GameCatalog.GameMode.Solo, family, controller, engine, verifier, configHash);
    }

    /// @notice Deploys a supported PvP-family module and registers it in the catalog.
    function deployPvPModule(uint8 family, bytes calldata deploymentParams)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (uint256 moduleId, address controller, address engine, address verifier)
    {
        if (family == uint8(MatchFamily.PokerSingleDraw2To7)) {
            PokerDeployment memory params = abi.decode(deploymentParams, (PokerDeployment));
            bytes32 engineType;
            (controller, engine, verifier, engineType) = POKER_MODULE_DEPLOYER.deployPvPModule(
                address(CATALOG),
                address(SETTLEMENT),
                params.coordinator,
                params.smallBlind,
                params.bigBlind,
                params.blindEscalationInterval,
                params.actionWindow,
                msg.sender
            );
            moduleId = _registerModule(
                GameCatalog.GameMode.PvP,
                controller,
                engine,
                engineType,
                verifier,
                params.configHash,
                params.developerRewardBps
            );

            emit ModuleDeployed(moduleId, GameCatalog.GameMode.PvP, family, controller, engine, verifier, params.configHash);
        } else if (family == uint8(MatchFamily.CheminDeFerBaccarat)) {
            CheminDeFerDeployment memory params = abi.decode(deploymentParams, (CheminDeFerDeployment));
            bytes32 engineType;
            (controller, engine, verifier, engineType) = CHEMIN_DE_FER_MODULE_DEPLOYER.deployCheminDeFerModule(
                address(CATALOG), address(SETTLEMENT), params.vrfCoordinator, params.joinWindow
            );
            moduleId = _registerModule(
                GameCatalog.GameMode.PvP,
                controller,
                engine,
                engineType,
                verifier,
                params.configHash,
                params.developerRewardBps
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
        bytes32 engineType;

        (controller, engine, verifier, engineType) = POKER_MODULE_DEPLOYER.deployTournamentModule(
            address(CATALOG),
            address(SETTLEMENT),
            params.coordinator,
            params.smallBlind,
            params.bigBlind,
            params.blindEscalationInterval,
            params.actionWindow,
            msg.sender
        );

        moduleId = _registerModule(
            GameCatalog.GameMode.Tournament,
            controller,
            engine,
            engineType,
            verifier,
            params.configHash,
            params.developerRewardBps
        );

        emit ModuleDeployed(
            moduleId, GameCatalog.GameMode.Tournament, family, controller, engine, verifier, params.configHash
        );
    }

    function _registerModule(
        GameCatalog.GameMode mode,
        address controller,
        address engine,
        bytes32 engineType,
        address verifier,
        bytes32 configHash,
        uint16 developerRewardBps
    ) internal returns (uint256 moduleId) {
        moduleId = CATALOG.registerModule(
            GameCatalog.Module({
                mode: mode,
                controller: controller,
                engine: engine,
                engineType: engineType,
                verifier: verifier,
                configHash: configHash,
                developerRewardBps: developerRewardBps,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );
    }
}
