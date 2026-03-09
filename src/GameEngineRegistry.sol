// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract GameEngineRegistry is AccessControl {
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    struct EngineMetadata {
        bytes32 engineType;
        address creator;
        address verifier;
        bytes32 configHash;
        uint16 creatorRateBps;
        bool active;
        bool supportsTournament;
        bool supportsPvP;
        bool supportsSolo;
    }

    mapping(address => EngineMetadata) private engines;

    event EngineRegistered(address indexed engine, bytes32 indexed engineType, address indexed creator);
    event EngineDeactivated(address indexed engine, bool active);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(REGISTRAR_ROLE, admin);
    }

    function registerEngine(address engine, EngineMetadata calldata metadata) external onlyRole(REGISTRAR_ROLE) {
        require(engine != address(0), "Registry: zero engine");
        require(metadata.creatorRateBps <= 10_000, "Registry: invalid bps");
        require(metadata.active, "Registry: engine must start active");
        engines[engine] = metadata;
        emit EngineRegistered(engine, metadata.engineType, metadata.creator);
    }

    function setEngineActive(address engine, bool active) external onlyRole(REGISTRAR_ROLE) {
        require(engines[engine].engineType != bytes32(0), "Registry: unknown");
        engines[engine].active = active;
        emit EngineDeactivated(engine, active);
    }

    function getEngineMetadata(address engine) external view returns (EngineMetadata memory) {
        return engines[engine];
    }

    function isActive(address engine) public view returns (bool) {
        return engines[engine].active;
    }

    function isRegisteredForTournament(address engine) external view returns (bool) {
        EngineMetadata memory metadata = engines[engine];
        return metadata.active && metadata.supportsTournament;
    }

    function isRegisteredForPvP(address engine) external view returns (bool) {
        EngineMetadata memory metadata = engines[engine];
        return metadata.active && metadata.supportsPvP;
    }

    function isRegisteredForSolo(address engine) external view returns (bool) {
        EngineMetadata memory metadata = engines[engine];
        return metadata.active && metadata.supportsSolo;
    }

    function getCreatorConfig(address engine) external view returns (address creator, uint16 creatorRateBps) {
        EngineMetadata memory metadata = engines[engine];
        return (metadata.creator, metadata.creatorRateBps);
    }
}
