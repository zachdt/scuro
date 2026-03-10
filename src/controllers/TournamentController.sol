// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {GameCatalog} from "../GameCatalog.sol";
import {ProtocolSettlement} from "../ProtocolSettlement.sol";
import {ITournamentGameEngine} from "../interfaces/ITournamentGameEngine.sol";

contract TournamentController is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    struct Tournament {
        bool active;
        uint256 entryFee;
        uint256 rewardPool;
        uint256 startingStack;
        uint256 expressionTokenId;
    }

    ProtocolSettlement internal immutable SETTLEMENT;
    GameCatalog internal immutable CATALOG;
    ITournamentGameEngine internal immutable ENGINE;

    uint256 public nextTournamentId = 1;
    uint256 public nextGameId = 1;

    mapping(uint256 => Tournament) public tournaments;
    mapping(uint256 => uint256) public gameToTournament;
    mapping(uint256 => bool) public gameReported;

    event TournamentCreated(
        uint256 indexed tournamentId,
        address indexed engine,
        uint256 indexed expressionTokenId,
        uint256 entryFee,
        uint256 rewardPool
    );
    event TournamentActiveSet(uint256 indexed tournamentId, bool active);
    event GameStarted(uint256 indexed tournamentId, uint256 indexed gameId, address player1, address player2);
    event GameSettled(uint256 indexed gameId, address indexed engine, uint256 indexed expressionTokenId);

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

    function createTournament(uint256 entryFee, uint256 rewardPool, uint256 startingStack, uint256 expressionTokenId)
        external
        onlyRole(OPERATOR_ROLE)
        returns (uint256 tournamentId)
    {
        require(CATALOG.isLaunchableController(address(this)), "TournamentController: module inactive");
        tournamentId = nextTournamentId++;
        tournaments[tournamentId] = Tournament({
            active: true,
            entryFee: entryFee,
            rewardPool: rewardPool,
            startingStack: startingStack,
            expressionTokenId: expressionTokenId
        });
        emit TournamentCreated(tournamentId, address(ENGINE), expressionTokenId, entryFee, rewardPool);
    }

    function setTournamentActive(uint256 tournamentId, bool active) external onlyRole(OPERATOR_ROLE) {
        tournaments[tournamentId].active = active;
        emit TournamentActiveSet(tournamentId, active);
    }

    function startGameForPlayers(uint256 tournamentId, address p1, address p2)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
        returns (uint256 gameId)
    {
        require(CATALOG.isLaunchableController(address(this)), "TournamentController: module inactive");
        Tournament memory tournament = tournaments[tournamentId];
        require(tournament.active, "TournamentController: inactive");

        if (tournament.entryFee > 0) {
            SETTLEMENT.burnPlayerWager(p1, tournament.entryFee);
            SETTLEMENT.burnPlayerWager(p2, tournament.entryFee);
        }

        gameId = nextGameId++;
        gameToTournament[gameId] = tournamentId;

        address[] memory players = new address[](2);
        players[0] = p1;
        players[1] = p2;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = tournament.startingStack;
        stacks[1] = tournament.startingStack;

        ENGINE.initializeGame(gameId, players, stacks, tournament.entryFee, tournament.rewardPool);

        emit GameStarted(tournamentId, gameId, p1, p2);
    }

    function reportOutcome(uint256 gameId) external nonReentrant {
        require(CATALOG.isSettlableController(address(this)), "TournamentController: module inactive");
        require(!gameReported[gameId], "TournamentController: reported");
        uint256 tournamentId = gameToTournament[gameId];
        Tournament memory tournament = tournaments[tournamentId];
        require(ENGINE.isGameOver(gameId), "TournamentController: game active");

        gameReported[gameId] = true;
        (address[] memory winners, uint256[] memory payouts) = ENGINE.getOutcomes(gameId);
        for (uint256 i = 0; i < winners.length; i++) {
            SETTLEMENT.mintPlayerReward(winners[i], payouts[i]);
        }

        SETTLEMENT.accrueDeveloperForExpression(tournament.expressionTokenId, tournament.rewardPool + (tournament.entryFee * 2));
        emit GameSettled(gameId, address(ENGINE), tournament.expressionTokenId);
    }
}
