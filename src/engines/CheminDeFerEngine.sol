// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {GameCatalog} from "../GameCatalog.sol";
import {BaccaratRules} from "../libraries/BaccaratRules.sol";
import {BaccaratTypes} from "../libraries/BaccaratTypes.sol";
import {ICheminDeFerEngine} from "../interfaces/ICheminDeFerEngine.sol";

/// @title Automated chemin de fer engine
/// @notice Requests VRF and stores one-shot baccarat round outcomes for player-banked tables.
contract CheminDeFerEngine is ICheminDeFerEngine {
    bytes32 public constant ENGINE_TYPE = keccak256("BACCARAT_CHEMIN_DE_FER_PVP");

    struct Resolution {
        bytes32 playRef;
        uint256 requestId;
        bool resolved;
        BaccaratTypes.BaccaratRoundView round;
    }

    GameCatalog internal immutable CATALOG;
    address public immutable vrfCoordinator;

    mapping(uint256 => Resolution) internal resolutions;
    mapping(uint256 => uint256) public requestToTableId;

    event ResolutionRequested(uint256 indexed tableId, uint256 indexed requestId, bytes32 indexed playRef);
    event ResolutionCompleted(uint256 indexed tableId, uint256 indexed requestId, BaccaratTypes.BaccaratOutcome outcome);

    constructor(address catalogAddress, address vrfCoordinatorAddress) {
        CATALOG = GameCatalog(catalogAddress);
        vrfCoordinator = vrfCoordinatorAddress;
    }

    function catalog() public view returns (GameCatalog) {
        return CATALOG;
    }

    function engineType() external pure returns (bytes32) {
        return ENGINE_TYPE;
    }

    function requestResolution(uint256 tableId, bytes32 playRef) external returns (uint256 requestId) {
        require(CATALOG.isAuthorizedControllerForEngine(msg.sender, address(this)), "CheminDeFer: not controller");
        Resolution storage resolution = resolutions[tableId];
        require(resolution.requestId == 0, "CheminDeFer: requested");

        requestId = _getNextRequestId();
        resolution.playRef = playRef;
        resolution.requestId = requestId;
        requestToTableId[requestId] = tableId;

        emit ResolutionRequested(tableId, requestId, playRef);

        uint256 actualId = _requestRandomness();
        require(actualId == requestId, "CheminDeFer: request mismatch");
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        require(CATALOG.isSettlableEngine(address(this)), "CheminDeFer: module inactive");
        require(msg.sender == vrfCoordinator, "CheminDeFer: bad coordinator");

        uint256 tableId = requestToTableId[requestId];
        require(tableId != 0, "CheminDeFer: unknown request");

        Resolution storage resolution = resolutions[tableId];
        require(!resolution.resolved, "CheminDeFer: resolved");

        resolution.round = BaccaratRules.resolve(randomWords[0]);
        resolution.resolved = true;

        emit ResolutionCompleted(tableId, requestId, resolution.round.outcome);
    }

    function isResolved(uint256 tableId) external view returns (bool resolved) {
        return resolutions[tableId].resolved;
    }

    function getRound(uint256 tableId)
        external
        view
        returns (
            uint8[3] memory playerCards,
            uint8[3] memory bankerCards,
            uint8 playerCardCount,
            uint8 bankerCardCount,
            uint8 playerTotal,
            uint8 bankerTotal,
            bool natural,
            BaccaratTypes.BaccaratOutcome outcome,
            uint256 randomWord,
            bool resolved,
            bytes32 playRef,
            uint256 requestId
        )
    {
        Resolution storage resolution = resolutions[tableId];
        return (
            resolution.round.playerCards,
            resolution.round.bankerCards,
            resolution.round.playerCardCount,
            resolution.round.bankerCardCount,
            resolution.round.playerTotal,
            resolution.round.bankerTotal,
            resolution.round.natural,
            resolution.round.outcome,
            resolution.round.randomWord,
            resolution.resolved,
            resolution.playRef,
            resolution.requestId
        );
    }

    function _getNextRequestId() internal view returns (uint256) {
        (bool success, bytes memory data) = vrfCoordinator.staticcall(abi.encodeWithSignature("requestCounter()"));
        require(success, "CheminDeFer: counter failed");
        return abi.decode(data, (uint256)) + 1;
    }

    function _requestRandomness() internal returns (uint256) {
        (bool success, bytes memory data) = vrfCoordinator.call(
            abi.encodeWithSignature(
                "requestRandomWords(bytes32,uint64,uint16,uint32,uint32)",
                bytes32(0),
                uint64(0),
                uint16(3),
                uint32(100000),
                uint32(1)
            )
        );
        require(success, "CheminDeFer: vrf failed");
        return abi.decode(data, (uint256));
    }
}
