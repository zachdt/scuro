// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {GameCatalog} from "./GameCatalog.sol";
import {ProtocolSettlement} from "./ProtocolSettlement.sol";
import {ISoloModuleDeployer} from "./factory/IModuleDeployers.sol";

/// @title Scuro game deployment factory
/// @notice Deploys shipped controller/engine bundles and registers them in the catalog.
contract GameDeploymentFactory is AccessControl {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    /// @notice Supported solo module families.
    enum SoloFamily {
        NumberPicker,
        SlotMachine
    }

    /// @notice ABI shape for deploying a NumberPicker module.
    struct NumberPickerDeployment {
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

    GameCatalog internal immutable CATALOG;
    ProtocolSettlement internal immutable SETTLEMENT;
    ISoloModuleDeployer internal immutable SOLO_MODULE_DEPLOYER;

    /// @notice Emitted when the factory deploys a new module bundle.
    event ModuleDeployed(
        uint256 indexed moduleId,
        uint8 indexed family,
        address controller,
        address engine,
        bytes32 configHash
    );

    /// @notice Initializes the factory and grants deploy permissions to the admin.
    constructor(
        address admin,
        address catalogAddress,
        address settlementAddress,
        address soloModuleDeployer
    ) {
        CATALOG = GameCatalog(catalogAddress);
        SETTLEMENT = ProtocolSettlement(settlementAddress);
        SOLO_MODULE_DEPLOYER = ISoloModuleDeployer(soloModuleDeployer);
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
        returns (uint256 moduleId, address controller, address engine)
    {
        bytes32 engineType;
        bytes32 configHash;
        uint16 developerRewardBps;

        if (family == uint8(SoloFamily.NumberPicker)) {
            NumberPickerDeployment memory params = abi.decode(deploymentParams, (NumberPickerDeployment));
            (controller, engine, engineType) = SOLO_MODULE_DEPLOYER.deployNumberPickerModule(
                address(CATALOG), address(SETTLEMENT), params.vrfCoordinator
            );
            configHash = params.configHash;
            developerRewardBps = params.developerRewardBps;
        } else if (family == uint8(SoloFamily.SlotMachine)) {
            SlotDeployment memory params = abi.decode(deploymentParams, (SlotDeployment));
            (controller, engine, engineType) = SOLO_MODULE_DEPLOYER.deploySlotMachineModule(
                address(CATALOG), address(SETTLEMENT), params.vrfCoordinator, msg.sender
            );
            configHash = params.configHash;
            developerRewardBps = params.developerRewardBps;
        } else {
            revert("Factory: unsupported solo family");
        }

        moduleId = _registerModule(controller, engine, engineType, configHash, developerRewardBps);
        emit ModuleDeployed(moduleId, family, controller, engine, configHash);
    }

    function _registerModule(
        address controller,
        address engine,
        bytes32 engineType,
        bytes32 configHash,
        uint16 developerRewardBps
    ) internal returns (uint256 moduleId) {
        moduleId = CATALOG.registerModule(
            GameCatalog.Module({
                controller: controller,
                engine: engine,
                engineType: engineType,
                configHash: configHash,
                developerRewardBps: developerRewardBps,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );
    }
}
