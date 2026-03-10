// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {GameEngineRegistry} from "../GameEngineRegistry.sol";
import {ProtocolSettlement} from "../ProtocolSettlement.sol";
import {SingleDeckBlackjackEngine} from "../engines/SingleDeckBlackjackEngine.sol";

contract BlackjackController is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    ProtocolSettlement internal immutable SETTLEMENT;
    GameEngineRegistry internal immutable REGISTRY;
    SingleDeckBlackjackEngine internal immutable ENGINE;

    mapping(uint256 => bool) public sessionSettled;

    event HandStarted(uint256 indexed sessionId, address indexed player, uint256 wager, bytes32 indexed playRef);
    event SessionSettled(uint256 indexed sessionId, address indexed player, uint256 payout, uint256 totalBurned);

    constructor(address admin, address settlementAddress, address registryAddress, address engineAddress) {
        SETTLEMENT = ProtocolSettlement(settlementAddress);
        REGISTRY = GameEngineRegistry(registryAddress);
        ENGINE = SingleDeckBlackjackEngine(engineAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    function settlement() public view returns (ProtocolSettlement) {
        return SETTLEMENT;
    }

    function registry() public view returns (GameEngineRegistry) {
        return REGISTRY;
    }

    function engine() public view returns (SingleDeckBlackjackEngine) {
        return ENGINE;
    }

    function startHand(uint256 wager, bytes32 playRef, bytes32 playerKeyCommitment) external returns (uint256 sessionId) {
        require(REGISTRY.isRegisteredForSolo(address(ENGINE)), "BlackjackController: engine inactive");
        SETTLEMENT.burnPlayerWager(msg.sender, wager);
        sessionId = ENGINE.openSession(msg.sender, wager, playRef, playerKeyCommitment);
        emit HandStarted(sessionId, msg.sender, wager, playRef);
    }

    function hit(uint256 sessionId) external {
        _declareAction(msg.sender, sessionId, ENGINE.ACTION_HIT());
    }

    function stand(uint256 sessionId) external {
        _declareAction(msg.sender, sessionId, ENGINE.ACTION_STAND());
    }

    function doubleDown(uint256 sessionId) external {
        _declareAction(msg.sender, sessionId, ENGINE.ACTION_DOUBLE());
    }

    function split(uint256 sessionId) external {
        _declareAction(msg.sender, sessionId, ENGINE.ACTION_SPLIT());
    }

    function claimPlayerTimeout(uint256 sessionId) external {
        ENGINE.claimPlayerTimeout(sessionId);
    }

    function settle(uint256 sessionId) external {
        require(!sessionSettled[sessionId], "BlackjackController: settled");
        (address player, uint256 totalBurned, uint256 payout, bool completed) = ENGINE.getSettlementOutcome(sessionId);
        require(completed, "BlackjackController: active");

        sessionSettled[sessionId] = true;
        if (payout > 0) {
            SETTLEMENT.mintPlayerReward(player, payout);
        }
        SETTLEMENT.accrueCreatorForEngine(address(ENGINE), totalBurned);
        emit SessionSettled(sessionId, player, payout, totalBurned);
    }

    function _declareAction(address player, uint256 sessionId, uint8 action) internal {
        uint256 additionalBurn = ENGINE.requiredAdditionalBurn(sessionId, action);
        if (additionalBurn > 0) {
            SETTLEMENT.burnPlayerWager(player, additionalBurn);
        }
        ENGINE.declareAction(sessionId, player, action, additionalBurn);
    }
}
