// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract GameCatalog is AccessControl {
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    enum GameMode {
        Solo,
        PvP,
        Tournament
    }

    enum ModuleStatus {
        LIVE,
        RETIRED,
        DISABLED
    }

    struct Module {
        GameMode mode;
        address controller;
        address engine;
        bytes32 engineType;
        address verifier;
        bytes32 configHash;
        uint16 developerRewardBps;
        ModuleStatus status;
    }

    uint256 public nextModuleId = 1;

    mapping(uint256 => Module) private modules;
    mapping(address => uint256) public controllerModuleIds;
    mapping(address => uint256) public engineModuleIds;

    event ModuleRegistered(
        uint256 indexed moduleId,
        GameMode indexed mode,
        address indexed controller,
        address engine,
        bytes32 engineType,
        address verifier,
        bytes32 configHash,
        uint16 developerRewardBps,
        ModuleStatus status
    );
    event ModuleStatusUpdated(uint256 indexed moduleId, ModuleStatus status);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(REGISTRAR_ROLE, admin);
    }

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
            moduleData.mode,
            moduleData.controller,
            moduleData.engine,
            moduleData.engineType,
            moduleData.verifier,
            moduleData.configHash,
            moduleData.developerRewardBps,
            moduleData.status
        );
    }

    function setModuleStatus(uint256 moduleId, ModuleStatus status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Module storage moduleData = modules[moduleId];
        require(moduleData.controller != address(0), "Catalog: unknown module");
        moduleData.status = status;
        emit ModuleStatusUpdated(moduleId, status);
    }

    function getModule(uint256 moduleId) public view returns (Module memory) {
        Module memory moduleData = modules[moduleId];
        require(moduleData.controller != address(0), "Catalog: unknown module");
        return moduleData;
    }

    function getModuleByController(address controller) public view returns (Module memory) {
        uint256 moduleId = controllerModuleIds[controller];
        require(moduleId != 0, "Catalog: unknown controller");
        return modules[moduleId];
    }

    function getModuleByEngine(address engine) public view returns (Module memory) {
        uint256 moduleId = engineModuleIds[engine];
        require(moduleId != 0, "Catalog: unknown engine");
        return modules[moduleId];
    }

    function isLaunchableController(address controller) public view returns (bool) {
        uint256 moduleId = controllerModuleIds[controller];
        return moduleId != 0 && modules[moduleId].status == ModuleStatus.LIVE;
    }

    function isSettlableController(address controller) public view returns (bool) {
        uint256 moduleId = controllerModuleIds[controller];
        if (moduleId == 0) {
            return false;
        }

        ModuleStatus status = modules[moduleId].status;
        return status == ModuleStatus.LIVE || status == ModuleStatus.RETIRED;
    }

    function isLaunchableEngine(address engine) public view returns (bool) {
        uint256 moduleId = engineModuleIds[engine];
        return moduleId != 0 && modules[moduleId].status == ModuleStatus.LIVE;
    }

    function isSettlableEngine(address engine) public view returns (bool) {
        uint256 moduleId = engineModuleIds[engine];
        if (moduleId == 0) {
            return false;
        }

        ModuleStatus status = modules[moduleId].status;
        return status == ModuleStatus.LIVE || status == ModuleStatus.RETIRED;
    }

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
