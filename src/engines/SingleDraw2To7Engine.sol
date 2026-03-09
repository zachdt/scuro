// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPokerVerifier} from "../interfaces/IPokerVerifier.sol";
import {IPokerZKEngine} from "../interfaces/IPokerZKEngine.sol";
import {PokerZKStatements} from "../libraries/PokerZKStatements.sol";

contract SingleDraw2To7Engine is IPokerZKEngine {
    using PokerZKStatements for bytes32;

    bytes32 public constant ENGINE_TYPE = keccak256("POKER_2_7_SINGLE_DRAW");

    enum MatchState {
        Inactive,
        Active,
        Completed
    }

    enum HandPhase {
        None,
        PreDraw,
        DrawProofPending,
        PostDraw,
        ShowdownProofPending,
        HandComplete
    }

    struct PlayerState {
        address addr;
        uint256 stack;
        uint256 currentBet;
        bool hasFolded;
        bool hasActed;
        bool hasDrawn;
    }

    struct PendingDraw {
        bytes32 newCommitment;
        bytes32 nullifier;
        uint256 nextProofSequence;
        bool exists;
    }

    struct Game {
        MatchState matchState;
        uint256 buyIn;
        uint256 reward;
        uint256 pot;
        uint256 highestBet;
        uint256 currentTurn;
        uint256 dealerIdx;
        uint256 currentSmallBlind;
        uint256 currentBigBlind;
        uint256 blindEscalationInterval;
        uint256 actionWindow;
        uint256 gameStartTime;
        address tournamentController;
        address drawVerifier;
        address showdownVerifier;
        address handCoordinator;
        address matchWinner;
        bool isTie;
        PlayerState[2] players;
        HandStateView hand;
        PendingDraw[2] pendingDraws;
    }

    mapping(uint256 => Game) public games;

    event HandInitialized(uint256 indexed gameId, uint256 indexed handNumber);
    event PublicActionTaken(uint256 indexed gameId, address indexed player, uint8 phase, uint256 amount);
    event DrawSubmitted(uint256 indexed gameId, address indexed player, bytes32 newCommitment);
    event ShowdownSubmitted(uint256 indexed gameId, address indexed submitter, address indexed winner, bool isTie);

    modifier onlyController(uint256 gameId) {
        _onlyController(gameId);
        _;
    }

    function _onlyController(uint256 gameId) internal view {
        require(msg.sender == games[gameId].tournamentController, "SingleDraw: not controller");
    }

    function engineType() external pure override returns (bytes32) {
        return ENGINE_TYPE;
    }

    function initializeGame(
        uint256 gameId,
        address[] calldata players,
        uint256[] calldata startingStacks,
        uint256 buyIn,
        uint256 reward,
        bytes calldata engineConfig
    ) external override {
        require(players.length == 2, "SingleDraw: two players");
        Game storage game = games[gameId];
        require(game.matchState == MatchState.Inactive, "SingleDraw: exists");

        (
            uint256 smallBlind,
            uint256 bigBlind,
            uint256 blindInterval,
            uint256 actionWindow,
            address drawVerifier,
            address showdownVerifier,
            address handCoordinator
        ) = _decodeConfig(engineConfig);

        game.matchState = MatchState.Active;
        game.buyIn = buyIn;
        game.reward = reward;
        game.currentSmallBlind = smallBlind;
        game.currentBigBlind = bigBlind;
        game.blindEscalationInterval = blindInterval;
        game.actionWindow = actionWindow;
        game.drawVerifier = drawVerifier;
        game.showdownVerifier = showdownVerifier;
        game.handCoordinator = handCoordinator;
        game.gameStartTime = block.timestamp;
        game.tournamentController = msg.sender;
        game.players[0] = PlayerState({
            addr: players[0],
            stack: startingStacks[0],
            currentBet: 0,
            hasFolded: false,
            hasActed: false,
            hasDrawn: false
        });
        game.players[1] = PlayerState({
            addr: players[1],
            stack: startingStacks[1],
            currentBet: 0,
            hasFolded: false,
            hasActed: false,
            hasDrawn: false
        });

        _startNextHand(game);
    }

    function bet(uint256 gameId, uint256 amount) external {
        Game storage game = games[gameId];
        require(game.matchState == MatchState.Active, "SingleDraw: inactive");
        require(
            game.hand.handPhase == uint8(HandPhase.PreDraw) || game.hand.handPhase == uint8(HandPhase.PostDraw),
            "SingleDraw: betting closed"
        );
        require(game.players[game.currentTurn].addr == msg.sender, "SingleDraw: not turn");
        _requireUnexpired(game);

        PlayerState storage player = game.players[game.currentTurn];
        if (amount == 0) {
            require(player.currentBet >= game.highestBet, "SingleDraw: call or raise");
        } else {
            uint256 totalBet = player.currentBet + amount;
            require(totalBet >= game.highestBet, "SingleDraw: bet low");
            require(player.stack >= amount, "SingleDraw: stack low");
            player.stack -= amount;
            player.currentBet = totalBet;
            game.pot += amount;
            if (totalBet > game.highestBet) {
                game.highestBet = totalBet;
                game.players[1 - game.currentTurn].hasActed = false;
            }
        }

        player.hasActed = true;
        emit PublicActionTaken(gameId, msg.sender, game.hand.handPhase, amount);
        _advanceAfterAction(gameId, game);
    }

    function fold(uint256 gameId) external {
        Game storage game = games[gameId];
        require(game.matchState == MatchState.Active, "SingleDraw: inactive");
        require(game.players[game.currentTurn].addr == msg.sender, "SingleDraw: not turn");
        _requireUnexpired(game);

        game.players[game.currentTurn].hasFolded = true;
        _completeHand(game, game.players[1 - game.currentTurn].addr, false);
    }

    function initializeHandState(
        uint256 gameId,
        bytes32 deckCommitment,
        bytes32 handNonce,
        bytes32[2] calldata handCommitments,
        bytes32[2] calldata encryptionKeyCommitments,
        bytes32[2] calldata ciphertextRefs
    ) external override {
        Game storage game = games[gameId];
        require(game.matchState == MatchState.Active, "SingleDraw: inactive");
        require(msg.sender == game.handCoordinator || msg.sender == game.tournamentController, "SingleDraw: bad init");

        game.hand.handNumber += 1;
        game.hand.handPhase = uint8(HandPhase.PreDraw);
        game.hand.deckCommitment = deckCommitment;
        game.hand.handNonce = handNonce;
        game.hand.handCommitments = handCommitments;
        game.hand.encryptionKeyCommitments = encryptionKeyCommitments;
        game.hand.ciphertextRefs = ciphertextRefs;
        game.hand.proofSequences[0] = 0;
        game.hand.proofSequences[1] = 0;
        game.hand.drawResolved[0] = false;
        game.hand.drawResolved[1] = false;
        game.hand.deadlineAt = block.timestamp + game.actionWindow;
        game.hand.expectedActor = uint8(game.currentTurn);
        emit HandInitialized(gameId, game.hand.handNumber);
    }

    function discardCards(uint256 gameId, uint8[] calldata cardIndices) external {
        Game storage game = games[gameId];
        require(game.matchState == MatchState.Active, "SingleDraw: inactive");
        require(game.hand.handPhase == uint8(HandPhase.DrawProofPending), "SingleDraw: not draw");

        uint256 playerIndex = _playerIndex(game, msg.sender);
        require(!game.players[playerIndex].hasDrawn, "SingleDraw: drew");
        require(cardIndices.length <= 5, "SingleDraw: too many");
        game.players[playerIndex].hasDrawn = true;
        game.hand.drawResolved[playerIndex] = true;

        if (game.hand.drawResolved[0] && game.hand.drawResolved[1]) {
            game.hand.handPhase = uint8(HandPhase.PostDraw);
            game.players[0].hasActed = false;
            game.players[1].hasActed = false;
            game.players[0].currentBet = 0;
            game.players[1].currentBet = 0;
            game.highestBet = 0;
            game.currentTurn = 1 - game.dealerIdx;
            game.hand.deadlineAt = block.timestamp + game.actionWindow;
            game.hand.expectedActor = uint8(game.currentTurn);
        }
    }

    function submitDrawProof(
        uint256 gameId,
        bytes32 newCommitment,
        bytes32 nullifier,
        bytes calldata proof
    ) external override {
        Game storage game = games[gameId];
        require(game.hand.handPhase == uint8(HandPhase.DrawProofPending), "SingleDraw: no draw");
        require(game.players[game.currentTurn].addr == msg.sender, "SingleDraw: not turn");
        _requireUnexpired(game);

        uint256 actor = game.currentTurn;
        bytes32 statementHash = PokerZKStatements.hashDrawStatement(
            ENGINE_TYPE,
            gameId,
            game.hand.handNumber,
            msg.sender,
            game.hand.handCommitments[actor],
            newCommitment,
            game.hand.deckCommitment,
            game.hand.handNonce,
            nullifier,
            game.hand.proofSequences[actor] + 1
        );

        if (game.drawVerifier != address(0)) {
            require(IPokerVerifier(game.drawVerifier).verify(proof, statementHash), "SingleDraw: invalid draw proof");
        }

        game.pendingDraws[actor] = PendingDraw({
            newCommitment: newCommitment,
            nullifier: nullifier,
            nextProofSequence: game.hand.proofSequences[actor] + 1,
            exists: true
        });
        emit DrawSubmitted(gameId, msg.sender, newCommitment);
    }

    function finalizeDraw(uint256 gameId, address player) external override {
        Game storage game = games[gameId];
        uint256 actor = _playerIndex(game, player);
        PendingDraw storage pending = game.pendingDraws[actor];
        require(pending.exists, "SingleDraw: no draw");

        game.hand.handCommitments[actor] = pending.newCommitment;
        game.hand.proofSequences[actor] = pending.nextProofSequence;
        game.hand.drawResolved[actor] = true;
        delete game.pendingDraws[actor];

        if (game.hand.drawResolved[0] && game.hand.drawResolved[1]) {
            game.hand.handPhase = uint8(HandPhase.PostDraw);
            game.players[0].hasActed = false;
            game.players[1].hasActed = false;
            game.players[0].currentBet = 0;
            game.players[1].currentBet = 0;
            game.highestBet = 0;
            game.currentTurn = 1 - game.dealerIdx;
            game.hand.deadlineAt = block.timestamp + game.actionWindow;
            game.hand.expectedActor = uint8(game.currentTurn);
        } else {
            game.currentTurn = 1 - actor;
            game.hand.expectedActor = uint8(game.currentTurn);
            game.hand.deadlineAt = block.timestamp + game.actionWindow;
        }
    }

    function submitShowdownProof(
        uint256 gameId,
        address winnerAddr,
        bool isTie,
        bytes calldata proof
    ) external override {
        Game storage game = games[gameId];
        require(game.hand.handPhase == uint8(HandPhase.ShowdownProofPending), "SingleDraw: no showdown");
        require(game.players[game.currentTurn].addr == msg.sender, "SingleDraw: not turn");
        _requireUnexpired(game);

        bytes32 statementHash = PokerZKStatements.hashShowdownStatement(
            ENGINE_TYPE,
            gameId,
            game.hand.handNumber,
            game.hand.handCommitments,
            winnerAddr,
            isTie,
            game.hand.handNonce
        );
        if (game.showdownVerifier != address(0)) {
            require(IPokerVerifier(game.showdownVerifier).verify(proof, statementHash), "SingleDraw: invalid showdown");
        }

        emit ShowdownSubmitted(gameId, msg.sender, winnerAddr, isTie);
        _completeHand(game, winnerAddr, isTie);
    }

    function resolveShowdown(uint256 gameId, address winnerAddr, bool isTie) external onlyController(gameId) {
        Game storage game = games[gameId];
        require(game.hand.handPhase == uint8(HandPhase.ShowdownProofPending), "SingleDraw: no showdown");
        _completeHand(game, winnerAddr, isTie);
    }

    function handleTimeout(uint256 gameId, address player) external override onlyController(gameId) {
        Game storage game = games[gameId];
        require(game.players[game.currentTurn].addr == player, "SingleDraw: wrong actor");
        require(block.timestamp > game.hand.deadlineAt, "SingleDraw: active");
        _completeHand(game, game.players[1 - game.currentTurn].addr, false);
    }

    function claimTimeout(uint256 gameId) external override {
        Game storage game = games[gameId];
        require(block.timestamp > game.hand.deadlineAt, "SingleDraw: active");
        _completeHand(game, game.players[1 - game.currentTurn].addr, false);
    }

    function isGameOver(uint256 gameId) public view override returns (bool isOver) {
        return games[gameId].matchState == MatchState.Completed;
    }

    function getOutcomes(uint256 gameId) external view override returns (address[] memory winners, uint256[] memory payouts) {
        Game storage game = games[gameId];
        require(game.matchState == MatchState.Completed, "SingleDraw: active");

        if (game.isTie) {
            winners = new address[](2);
            winners[0] = game.players[0].addr;
            winners[1] = game.players[1].addr;
            payouts = new uint256[](2);
            payouts[0] = game.reward / 2;
            payouts[1] = game.reward - payouts[0];
        } else {
            winners = new address[](1);
            winners[0] = game.matchWinner;
            payouts = new uint256[](1);
            payouts[0] = game.reward;
        }
    }

    function getHandState(uint256 gameId) external view override returns (HandStateView memory) {
        return games[gameId].hand;
    }

    function getCurrentPhase(uint256 gameId) external view override returns (uint8) {
        return games[gameId].hand.handPhase;
    }

    function getProofDeadline(uint256 gameId) external view override returns (uint256) {
        return games[gameId].hand.deadlineAt;
    }

    function _advanceAfterAction(uint256 gameId, Game storage game) internal {
        if (game.players[0].hasActed && game.players[1].hasActed && game.players[0].currentBet == game.players[1].currentBet) {
            game.players[0].currentBet = 0;
            game.players[1].currentBet = 0;
            game.players[0].hasActed = false;
            game.players[1].hasActed = false;
            game.highestBet = 0;

            if (game.hand.handPhase == uint8(HandPhase.PreDraw)) {
                game.hand.handPhase = uint8(HandPhase.DrawProofPending);
                game.currentTurn = 1 - game.dealerIdx;
            } else {
                game.hand.handPhase = uint8(HandPhase.ShowdownProofPending);
                game.currentTurn = 1 - game.dealerIdx;
            }
            game.hand.expectedActor = uint8(game.currentTurn);
            game.hand.deadlineAt = block.timestamp + game.actionWindow;
        } else {
            game.currentTurn = 1 - game.currentTurn;
            game.hand.expectedActor = uint8(game.currentTurn);
            game.hand.deadlineAt = block.timestamp + game.actionWindow;
        }

        emit PublicActionTaken(gameId, game.players[1 - game.currentTurn].addr, game.hand.handPhase, 0);
    }

    function _startNextHand(Game storage game) internal {
        game.hand.handPhase = uint8(HandPhase.PreDraw);
        game.hand.handNumber += 1;
        game.hand.deadlineAt = block.timestamp + game.actionWindow;
        game.players[0].hasActed = false;
        game.players[1].hasActed = false;
        game.players[0].hasDrawn = false;
        game.players[1].hasDrawn = false;
        game.players[0].currentBet = 0;
        game.players[1].currentBet = 0;
        game.players[0].hasFolded = false;
        game.players[1].hasFolded = false;
        game.pot = 0;

        uint256 elapsed = block.timestamp - game.gameStartTime;
        uint256 level = game.blindEscalationInterval == 0 ? 0 : elapsed / game.blindEscalationInterval;
        uint256 multiplier = 2 ** level;
        uint256 smallBlind = game.currentSmallBlind * multiplier;
        uint256 bigBlind = game.currentBigBlind * multiplier;

        uint256 sbIdx = game.dealerIdx;
        uint256 bbIdx = 1 - game.dealerIdx;

        uint256 sbCost = smallBlind > game.players[sbIdx].stack ? game.players[sbIdx].stack : smallBlind;
        uint256 bbCost = bigBlind > game.players[bbIdx].stack ? game.players[bbIdx].stack : bigBlind;

        game.players[sbIdx].stack -= sbCost;
        game.players[sbIdx].currentBet = sbCost;
        game.players[bbIdx].stack -= bbCost;
        game.players[bbIdx].currentBet = bbCost;
        game.pot = sbCost + bbCost;
        game.highestBet = bbCost;
        game.currentTurn = sbIdx;
        game.hand.expectedActor = uint8(game.currentTurn);
    }

    function _completeHand(Game storage game, address winnerAddr, bool isTie) internal {
        if (isTie) {
            uint256 half = game.pot / 2;
            game.players[0].stack += half;
            game.players[1].stack += (game.pot - half);
        } else {
            uint256 winnerIndex = game.players[0].addr == winnerAddr ? 0 : 1;
            game.players[winnerIndex].stack += game.pot;
        }

        game.hand.handPhase = uint8(HandPhase.HandComplete);
        if (game.players[0].stack == 0 || game.players[1].stack == 0) {
            game.matchState = MatchState.Completed;
            game.matchWinner = game.players[0].stack > 0 ? game.players[0].addr : game.players[1].addr;
            game.isTie = isTie;
            return;
        }

        game.dealerIdx = 1 - game.dealerIdx;
        _startNextHand(game);
    }

    function _playerIndex(Game storage game, address player) internal view returns (uint256) {
        if (game.players[0].addr == player) {
            return 0;
        }
        require(game.players[1].addr == player, "SingleDraw: not player");
        return 1;
    }

    function _requireUnexpired(Game storage game) internal view {
        require(block.timestamp <= game.hand.deadlineAt, "SingleDraw: expired");
    }

    function _decodeConfig(bytes calldata raw)
        internal
        pure
        returns (
            uint256 smallBlind,
            uint256 bigBlind,
            uint256 blindInterval,
            uint256 actionWindow,
            address drawVerifier,
            address showdownVerifier,
            address handCoordinator
        )
    {
        if (raw.length == 0) {
            return (10, 20, 180, 60, address(0), address(0), address(0));
        }
        return abi.decode(raw, (uint256, uint256, uint256, uint256, address, address, address));
    }
}
