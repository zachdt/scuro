// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {GameCatalog} from "../GameCatalog.sol";
import {ProtocolSettlement} from "../ProtocolSettlement.sol";
import {ITournamentGameEngine} from "../interfaces/ITournamentGameEngine.sol";

contract PvPController is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    struct Session {
        bool active;
        address player1;
        address player2;
        uint256 stake;
        uint256 rewardPool;
        uint256 startingStack;
        uint256 expressionTokenId;
    }

    ProtocolSettlement internal immutable SETTLEMENT;
    GameCatalog internal immutable CATALOG;
    ITournamentGameEngine internal immutable ENGINE;
    uint256 public nextSessionId = 1;
    mapping(uint256 => Session) public sessions;
    mapping(uint256 => bool) public sessionSettled;

    event SessionCreated(
        uint256 indexed sessionId,
        address indexed engine,
        uint256 indexed expressionTokenId,
        address player1,
        address player2
    );
    event SessionSettled(uint256 indexed sessionId, address indexed engine, uint256 indexed expressionTokenId);

    constructor(address admin, address settlementAddress, address catalogAddress, address engineAddress) {
        SETTLEMENT = ProtocolSettlement(settlementAddress);
        CATALOG = GameCatalog(catalogAddress);
        ENGINE = ITournamentGameEngine(engineAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    function settlement() public view returns (ProtocolSettlement) {
        return SETTLEMENT;
    }

    function catalog() public view returns (GameCatalog) {
        return CATALOG;
    }

    function engine() public view returns (ITournamentGameEngine) {
        return ENGINE;
    }

    function createSession(
        address player1,
        address player2,
        uint256 stake,
        uint256 rewardPool,
        uint256 startingStack,
        uint256 expressionTokenId
    ) external onlyRole(OPERATOR_ROLE) returns (uint256 sessionId) {
        require(CATALOG.isLaunchableController(address(this)), "PvPController: module inactive");
        if (stake > 0) {
            SETTLEMENT.burnPlayerWager(player1, stake);
            SETTLEMENT.burnPlayerWager(player2, stake);
        }

        sessionId = nextSessionId++;
        sessions[sessionId] = Session({
            active: true,
            player1: player1,
            player2: player2,
            stake: stake,
            rewardPool: rewardPool,
            startingStack: startingStack,
            expressionTokenId: expressionTokenId
        });

        address[] memory players = new address[](2);
        players[0] = player1;
        players[1] = player2;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = startingStack;
        stacks[1] = startingStack;

        ENGINE.initializeGame(sessionId, players, stacks, stake, rewardPool);

        emit SessionCreated(sessionId, address(ENGINE), expressionTokenId, player1, player2);
    }

    function settleSession(uint256 sessionId) external nonReentrant {
        require(CATALOG.isSettlableController(address(this)), "PvPController: module inactive");
        require(!sessionSettled[sessionId], "PvPController: settled");
        Session memory session = sessions[sessionId];
        require(session.active, "PvPController: inactive");
        require(ENGINE.isGameOver(sessionId), "PvPController: game active");

        sessionSettled[sessionId] = true;
        (address[] memory winners, uint256[] memory payouts) = ENGINE.getOutcomes(sessionId);
        for (uint256 i = 0; i < winners.length; i++) {
            SETTLEMENT.mintPlayerReward(winners[i], payouts[i]);
        }

        SETTLEMENT.accrueDeveloperForExpression(session.expressionTokenId, session.rewardPool + (session.stake * 2));
        emit SessionSettled(sessionId, address(ENGINE), session.expressionTokenId);
    }
}
