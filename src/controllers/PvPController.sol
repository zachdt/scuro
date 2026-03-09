// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {GameEngineRegistry} from "../GameEngineRegistry.sol";
import {ProtocolSettlement} from "../ProtocolSettlement.sol";
import {ITournamentGameEngine} from "../interfaces/ITournamentGameEngine.sol";

contract PvPController is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    struct Session {
        bool active;
        address gameEngine;
        address player1;
        address player2;
        uint256 stake;
        uint256 rewardPool;
        uint256 startingStack;
        bytes engineConfig;
    }

    ProtocolSettlement internal immutable SETTLEMENT;
    GameEngineRegistry internal immutable REGISTRY;
    uint256 public nextSessionId = 1;
    mapping(uint256 => Session) public sessions;
    mapping(uint256 => bool) public sessionSettled;

    event SessionCreated(uint256 indexed sessionId, address indexed engine, address indexed player1, address player2);
    event SessionSettled(uint256 indexed sessionId, address indexed engine);

    constructor(address admin, address settlementAddress, address registryAddress) {
        SETTLEMENT = ProtocolSettlement(settlementAddress);
        REGISTRY = GameEngineRegistry(registryAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    function settlement() public view returns (ProtocolSettlement) {
        return SETTLEMENT;
    }

    function registry() public view returns (GameEngineRegistry) {
        return REGISTRY;
    }

    function createSession(
        address gameEngine,
        address player1,
        address player2,
        uint256 stake,
        uint256 rewardPool,
        uint256 startingStack,
        bytes calldata engineConfig
    ) external onlyRole(OPERATOR_ROLE) returns (uint256 sessionId) {
        require(REGISTRY.isRegisteredForPvP(gameEngine), "PvPController: engine inactive");
        if (stake > 0) {
            SETTLEMENT.burnPlayerWager(player1, stake);
            SETTLEMENT.burnPlayerWager(player2, stake);
        }

        sessionId = nextSessionId++;
        sessions[sessionId] = Session({
            active: true,
            gameEngine: gameEngine,
            player1: player1,
            player2: player2,
            stake: stake,
            rewardPool: rewardPool,
            startingStack: startingStack,
            engineConfig: engineConfig
        });

        address[] memory players = new address[](2);
        players[0] = player1;
        players[1] = player2;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = startingStack;
        stacks[1] = startingStack;

        ITournamentGameEngine(gameEngine).initializeGame(
            sessionId,
            players,
            stacks,
            stake,
            rewardPool,
            engineConfig
        );

        emit SessionCreated(sessionId, gameEngine, player1, player2);
    }

    function settleSession(uint256 sessionId) external nonReentrant {
        require(!sessionSettled[sessionId], "PvPController: settled");
        Session memory session = sessions[sessionId];
        require(session.active, "PvPController: inactive");
        require(ITournamentGameEngine(session.gameEngine).isGameOver(sessionId), "PvPController: game active");

        sessionSettled[sessionId] = true;
        (address[] memory winners, uint256[] memory payouts) = ITournamentGameEngine(session.gameEngine).getOutcomes(sessionId);
        for (uint256 i = 0; i < winners.length; i++) {
            SETTLEMENT.mintPlayerReward(winners[i], payouts[i]);
        }

        SETTLEMENT.accrueCreatorForEngine(session.gameEngine, session.rewardPool + (session.stake * 2));
        emit SessionSettled(sessionId, session.gameEngine);
    }
}
