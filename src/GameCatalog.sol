// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

/// @title Scuro game catalog
/// @notice Tracks the controller, engine, and lifecycle metadata for every registered module.
contract GameCatalog is AccessControl {
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    /// @notice Lifecycle gates that control whether modules can launch or settle.
    enum ModuleStatus {
        LIVE,
        RETIRED,
        DISABLED
    }

    /// @notice The canonical metadata stored for each module id.
    struct Module {
        address controller;
        address engine;
        bytes32 engineType;
        bytes32 configHash;
        uint16 developerRewardBps;
        ModuleStatus status;
    }

    uint256 public nextModuleId = 1;

    mapping(uint256 => Module) private modules;
    mapping(address => uint256) public controllerModuleIds;
    mapping(address => uint256) public engineModuleIds;

    /// @notice Emitted when a new module is registered.
    event ModuleRegistered(
        uint256 indexed moduleId,
        address indexed controller,
        address engine,
        bytes32 engineType,
        bytes32 configHash,
        uint16 developerRewardBps,
        ModuleStatus status
    );
    /// @notice Emitted when a module lifecycle state changes.
    event ModuleStatusUpdated(uint256 indexed moduleId, ModuleStatus status);

    /// @notice Initializes the catalog and grants admin and registrar roles.
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(REGISTRAR_ROLE, admin);
    }

    /// @notice Registers a controller/engine module and returns its assigned id.
    function registerModule(Module calldata moduleData) external onlyRole(REGISTRAR_ROLE) returns (uint256 moduleId) {
        require(moduleData.controller != address(0), "Catalog: zero controller");
        require(moduleData.engine != address(0), "Catalog: zero engine");
        require(moduleData.engineType != bytes32(0), "Catalog: zero type");
        require(moduleData.developerRewardBps <= 10_000, "Catalog: invalid bps");
        require(controllerModuleIds[moduleData.controller] == 0, "Catalog: controller exists");
        require(engineModuleIds[moduleData.engine] == 0, "Catalog: engine exists");

        moduleId = nextModuleId++;
        modules[moduleId] = moduleData;
        controllerModuleIds[moduleData.controller] = moduleId;
        engineModuleIds[moduleData.engine] = moduleId;

        emit ModuleRegistered(
            moduleId,
            moduleData.controller,
            moduleData.engine,
            moduleData.engineType,
            moduleData.configHash,
            moduleData.developerRewardBps,
            moduleData.status
        );
    }

    /// @notice Updates the lifecycle status for an existing module.
    function setModuleStatus(uint256 moduleId, ModuleStatus status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Module storage moduleData = modules[moduleId];
        require(moduleData.controller != address(0), "Catalog: unknown module");
        moduleData.status = status;
        emit ModuleStatusUpdated(moduleId, status);
    }

    /// @notice Returns module metadata by module id.
    function getModule(uint256 moduleId) public view returns (Module memory) {
        Module memory moduleData = modules[moduleId];
        require(moduleData.controller != address(0), "Catalog: unknown module");
        return moduleData;
    }

    /// @notice Returns module metadata indexed by controller address.
    function getModuleByController(address controller) public view returns (Module memory) {
        uint256 moduleId = controllerModuleIds[controller];
        require(moduleId != 0, "Catalog: unknown controller");
        return modules[moduleId];
    }

    /// @notice Returns module metadata indexed by engine address.
    function getModuleByEngine(address engine) public view returns (Module memory) {
        uint256 moduleId = engineModuleIds[engine];
        require(moduleId != 0, "Catalog: unknown engine");
        return modules[moduleId];
    }

    /// @notice Returns whether a controller can launch new sessions.
    function isLaunchableController(address controller) public view returns (bool) {
        uint256 moduleId = controllerModuleIds[controller];
        return moduleId != 0 && modules[moduleId].status == ModuleStatus.LIVE;
    }

    /// @notice Returns whether a controller can still settle existing sessions.
    function isSettlableController(address controller) public view returns (bool) {
        uint256 moduleId = controllerModuleIds[controller];
        if (moduleId == 0) {
            return false;
        }

        ModuleStatus status = modules[moduleId].status;
        return status == ModuleStatus.LIVE || status == ModuleStatus.RETIRED;
    }

    /// @notice Returns whether an engine can launch new sessions.
    function isLaunchableEngine(address engine) public view returns (bool) {
        uint256 moduleId = engineModuleIds[engine];
        return moduleId != 0 && modules[moduleId].status == ModuleStatus.LIVE;
    }

    /// @notice Returns whether an engine can continue progressing and settle existing sessions.
    function isSettlableEngine(address engine) public view returns (bool) {
        uint256 moduleId = engineModuleIds[engine];
        if (moduleId == 0) {
            return false;
        }

        ModuleStatus status = modules[moduleId].status;
        return status == ModuleStatus.LIVE || status == ModuleStatus.RETIRED;
    }

    /// @notice Returns whether the controller is the registered settlable controller for the engine.
    function isAuthorizedControllerForEngine(address controller, address engine) public view returns (bool) {
        uint256 moduleId = controllerModuleIds[controller];
        if (moduleId == 0) {
            return false;
        }

        Module memory moduleData = modules[moduleId];
        return moduleData.engine == engine
            && (moduleData.status == ModuleStatus.LIVE || moduleData.status == ModuleStatus.RETIRED);
    }
}
