// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../ProtocolSettlement.sol";
import "../GameEngineRegistry.sol";
import "../interfaces/ITournamentGameEngine.sol";

contract TournamentController is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    struct Tournament {
        bool active;
        uint256 entryFee;
        uint256 rewardPool;
        address gameEngine;
        uint256 startingStack;
        bytes engineConfig;
    }

    ProtocolSettlement public immutable settlement;
    GameEngineRegistry public immutable registry;

    uint256 public nextTournamentId = 1;
    uint256 public nextGameId = 1;

    mapping(uint256 => Tournament) public tournaments;
    mapping(uint256 => uint256) public gameToTournament;
    mapping(uint256 => bool) public gameReported;

    event TournamentCreated(uint256 indexed tournamentId, address indexed engine, uint256 entryFee, uint256 rewardPool);
    event TournamentActiveSet(uint256 indexed tournamentId, bool active);
    event GameStarted(uint256 indexed tournamentId, uint256 indexed gameId, address player1, address player2);
    event GameSettled(uint256 indexed gameId, address indexed engine);

    constructor(address admin, address settlementAddress, address registryAddress) {
        settlement = ProtocolSettlement(settlementAddress);
        registry = GameEngineRegistry(registryAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    function createTournament(
        uint256 entryFee,
        uint256 rewardPool,
        address gameEngine,
        uint256 startingStack,
        bytes calldata engineConfig
    ) external onlyRole(OPERATOR_ROLE) returns (uint256 tournamentId) {
        require(registry.isRegisteredForTournament(gameEngine), "TournamentController: engine inactive");
        tournamentId = nextTournamentId++;
        tournaments[tournamentId] = Tournament({
            active: true,
            entryFee: entryFee,
            rewardPool: rewardPool,
            gameEngine: gameEngine,
            startingStack: startingStack,
            engineConfig: engineConfig
        });
        emit TournamentCreated(tournamentId, gameEngine, entryFee, rewardPool);
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
        Tournament memory tournament = tournaments[tournamentId];
        require(tournament.active, "TournamentController: inactive");

        if (tournament.entryFee > 0) {
            settlement.burnPlayerWager(p1, tournament.entryFee);
            settlement.burnPlayerWager(p2, tournament.entryFee);
        }

        gameId = nextGameId++;
        gameToTournament[gameId] = tournamentId;

        address[] memory players = new address[](2);
        players[0] = p1;
        players[1] = p2;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = tournament.startingStack;
        stacks[1] = tournament.startingStack;

        ITournamentGameEngine(tournament.gameEngine).initializeGame(
            gameId,
            players,
            stacks,
            tournament.entryFee,
            tournament.rewardPool,
            tournament.engineConfig
        );

        emit GameStarted(tournamentId, gameId, p1, p2);
    }

    function reportOutcome(uint256 gameId) external nonReentrant {
        require(!gameReported[gameId], "TournamentController: reported");
        uint256 tournamentId = gameToTournament[gameId];
        Tournament memory tournament = tournaments[tournamentId];
        require(registry.isRegisteredForTournament(tournament.gameEngine), "TournamentController: engine inactive");
        require(ITournamentGameEngine(tournament.gameEngine).isGameOver(gameId), "TournamentController: game active");

        gameReported[gameId] = true;
        (address[] memory winners, uint256[] memory payouts) = ITournamentGameEngine(tournament.gameEngine).getOutcomes(gameId);
        for (uint256 i = 0; i < winners.length; i++) {
            settlement.mintPlayerReward(winners[i], payouts[i]);
        }

        settlement.accrueCreatorForEngine(tournament.gameEngine, tournament.rewardPool + (tournament.entryFee * 2));
        emit GameSettled(gameId, tournament.gameEngine);
    }
}
