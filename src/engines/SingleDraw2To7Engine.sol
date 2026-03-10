// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {GameCatalog} from "../GameCatalog.sol";
import {IPokerEngine} from "../interfaces/IPokerEngine.sol";
import {IPokerVerifierBundle} from "../interfaces/IPokerVerifierBundle.sol";
import {IPokerZKEngine} from "../interfaces/IPokerZKEngine.sol";

contract SingleDraw2To7Engine is IPokerZKEngine {
    bytes32 public constant ENGINE_TYPE = keccak256("POKER_2_7_SINGLE_DRAW");
    uint8 internal constant COORDINATOR_ACTOR = type(uint8).max;

    enum MatchState {
        Inactive,
        Active,
        Completed
    }

    enum HandPhase {
        None,
        AwaitingInitialDeal,
        PreDrawBetting,
        DrawDeclaration,
        DrawProofPending,
        PostDrawBetting,
        ShowdownProofPending,
        HandComplete
    }

    struct PlayerState {
        address addr;
        uint256 stack;
        uint256 currentBet;
        bool hasFolded;
        bool hasActed;
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
        address verifierBundle;
        address handCoordinator;
        address matchWinner;
        bool isTie;
        PlayerState[2] players;
        HandStateView hand;
    }

    GameCatalog internal immutable CATALOG;
    uint256 public immutable DEFAULT_SMALL_BLIND;
    uint256 public immutable DEFAULT_BIG_BLIND;
    uint256 public immutable BLIND_ESCALATION_INTERVAL;
    uint256 public immutable ACTION_WINDOW;
    address public immutable VERIFIER_BUNDLE;
    address public immutable HAND_COORDINATOR;

    mapping(uint256 => Game) public games;

    event HandAwaitingInitialDeal(uint256 indexed gameId, uint256 indexed handNumber);
    event PublicActionTaken(uint256 indexed gameId, address indexed player, uint8 phase, uint256 amount);
    event DrawDeclared(uint256 indexed gameId, address indexed player, uint8 discardMask);
    event DrawResolved(uint256 indexed gameId, address indexed player, bytes32 newCommitment);
    event ShowdownSubmitted(uint256 indexed gameId, address indexed submitter, address indexed winner, bool isTie);

    modifier onlyController(uint256 gameId) {
        require(msg.sender == games[gameId].tournamentController, "SingleDraw: not controller");
        _;
    }

    modifier onlyCoordinator(uint256 gameId) {
        Game storage game = games[gameId];
        require(
            msg.sender == game.handCoordinator || msg.sender == game.tournamentController, "SingleDraw: not coordinator"
        );
        _;
    }

    constructor(
        address catalogAddress,
        uint256 smallBlind,
        uint256 bigBlind,
        uint256 blindInterval,
        uint256 actionWindow,
        address verifierBundle,
        address handCoordinator
    ) {
        CATALOG = GameCatalog(catalogAddress);
        DEFAULT_SMALL_BLIND = smallBlind;
        DEFAULT_BIG_BLIND = bigBlind;
        BLIND_ESCALATION_INTERVAL = blindInterval;
        ACTION_WINDOW = actionWindow;
        VERIFIER_BUNDLE = verifierBundle;
        HAND_COORDINATOR = handCoordinator;
    }

    function catalog() public view returns (GameCatalog) {
        return CATALOG;
    }

    function engineType() external pure override returns (bytes32) {
        return ENGINE_TYPE;
    }

    function initializeGame(
        uint256 gameId,
        address[] calldata players,
        uint256[] calldata startingStacks,
        uint256 buyIn,
        uint256 reward
    ) external override {
        require(CATALOG.isAuthorizedControllerForEngine(msg.sender, address(this)), "SingleDraw: not controller");
        require(players.length == 2, "SingleDraw: two players");
        Game storage game = games[gameId];
        require(game.matchState == MatchState.Inactive, "SingleDraw: exists");

        game.matchState = MatchState.Active;
        game.buyIn = buyIn;
        game.reward = reward;
        game.currentSmallBlind = DEFAULT_SMALL_BLIND;
        game.currentBigBlind = DEFAULT_BIG_BLIND;
        game.blindEscalationInterval = BLIND_ESCALATION_INTERVAL;
        game.actionWindow = ACTION_WINDOW;
        game.verifierBundle = VERIFIER_BUNDLE;
        game.handCoordinator = HAND_COORDINATOR;
        game.gameStartTime = block.timestamp;
        game.tournamentController = msg.sender;
        game.players[0] = PlayerState(players[0], startingStacks[0], 0, false, false);
        game.players[1] = PlayerState(players[1], startingStacks[1], 0, false, false);

        _startNextHand(gameId, game);
    }

    function bet(uint256 gameId, uint256 amount) external {
        _requireSettlableModule();

        Game storage game = games[gameId];
        require(game.matchState == MatchState.Active, "SingleDraw: inactive");
        require(
            game.hand.handPhase == uint8(HandPhase.PreDrawBetting)
                || game.hand.handPhase == uint8(HandPhase.PostDrawBetting),
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
        _advanceAfterBettingAction(game, false);
    }

    function fold(uint256 gameId) external {
        _requireSettlableModule();

        Game storage game = games[gameId];
        require(game.matchState == MatchState.Active, "SingleDraw: inactive");
        require(
            game.hand.handPhase == uint8(HandPhase.PreDrawBetting)
                || game.hand.handPhase == uint8(HandPhase.PostDrawBetting),
            "SingleDraw: fold closed"
        );
        require(game.players[game.currentTurn].addr == msg.sender, "SingleDraw: not turn");
        _requireUnexpired(game);

        game.players[game.currentTurn].hasFolded = true;
        _completeHand(gameId, game, game.players[1 - game.currentTurn].addr, false);
    }

    function submitInitialDealProof(
        uint256 gameId,
        bytes32 deckCommitment,
        bytes32 handNonce,
        bytes32[2] calldata handCommitments,
        bytes32[2] calldata encryptionKeyCommitments,
        bytes32[2] calldata ciphertextRefs,
        bytes calldata proof
    ) external override onlyCoordinator(gameId) {
        _requireSettlableModule();
        _submitInitialDealProof(
            gameId, deckCommitment, handNonce, handCommitments, encryptionKeyCommitments, ciphertextRefs, proof
        );
    }

    function _submitInitialDealProof(
        uint256 gameId,
        bytes32 deckCommitment,
        bytes32 handNonce,
        bytes32[2] calldata handCommitments,
        bytes32[2] calldata encryptionKeyCommitments,
        bytes32[2] calldata ciphertextRefs,
        bytes memory proof
    ) internal {
        Game storage game = games[gameId];
        require(game.matchState == MatchState.Active, "SingleDraw: inactive");
        require(game.hand.handPhase == uint8(HandPhase.AwaitingInitialDeal), "SingleDraw: bad init phase");

        if (game.verifierBundle != address(0)) {
            IPokerVerifierBundle.InitialDealPublicInputs memory inputs = IPokerVerifierBundle.InitialDealPublicInputs({
                gameId: gameId,
                handNumber: game.hand.handNumber,
                handNonce: uint256(handNonce),
                deckCommitment: uint256(deckCommitment),
                handCommitments: [uint256(handCommitments[0]), uint256(handCommitments[1])],
                encryptionKeyCommitments: [uint256(encryptionKeyCommitments[0]), uint256(encryptionKeyCommitments[1])],
                ciphertextRefs: [uint256(ciphertextRefs[0]), uint256(ciphertextRefs[1])]
            });
            require(
                IPokerVerifierBundle(game.verifierBundle).verifyInitialDeal(proof, inputs),
                "SingleDraw: invalid init proof"
            );
        }

        game.hand.handPhase = uint8(HandPhase.PreDrawBetting);
        game.hand.deckCommitment = deckCommitment;
        game.hand.handNonce = handNonce;
        game.hand.handCommitments = handCommitments;
        game.hand.encryptionKeyCommitments = encryptionKeyCommitments;
        game.hand.ciphertextRefs = ciphertextRefs;
        game.hand.proofSequences[0] = 0;
        game.hand.proofSequences[1] = 0;
        game.hand.drawResolved[0] = false;
        game.hand.drawResolved[1] = false;
        game.hand.drawDeclared[0] = false;
        game.hand.drawDeclared[1] = false;
        game.hand.declaredDrawMasks[0] = 0;
        game.hand.declaredDrawMasks[1] = 0;
        game.hand.deadlineAt = block.timestamp + game.actionWindow;
        game.hand.expectedActor = uint8(game.currentTurn);
    }

    function declareDraw(uint256 gameId, uint8[] calldata cardIndices) external override {
        _requireSettlableModule();
        _declareDraw(gameId, cardIndices);
    }

    function _declareDraw(uint256 gameId, uint8[] calldata cardIndices) internal {
        Game storage game = games[gameId];
        require(game.matchState == MatchState.Active, "SingleDraw: inactive");
        require(game.hand.handPhase == uint8(HandPhase.DrawDeclaration), "SingleDraw: not draw");
        require(game.players[game.currentTurn].addr == msg.sender, "SingleDraw: not turn");
        _requireUnexpired(game);

        uint256 actor = game.currentTurn;
        require(!game.hand.drawDeclared[actor], "SingleDraw: declared");
        uint8 discardMask = _drawMask(cardIndices);

        game.hand.drawDeclared[actor] = true;
        game.hand.declaredDrawMasks[actor] = discardMask;
        emit DrawDeclared(gameId, msg.sender, discardMask);

        if (game.hand.drawDeclared[0] && game.hand.drawDeclared[1]) {
            game.hand.handPhase = uint8(HandPhase.DrawProofPending);
            game.hand.expectedActor = COORDINATOR_ACTOR;
            game.hand.deadlineAt = 0;
        } else {
            game.currentTurn = 1 - actor;
            game.hand.expectedActor = uint8(game.currentTurn);
            game.hand.deadlineAt = block.timestamp + game.actionWindow;
        }
    }

    function submitDrawProof(
        uint256 gameId,
        address player,
        bytes32 newCommitment,
        bytes32 newEncryptionKeyCommitment,
        bytes32 newCiphertextRef,
        bytes calldata proof
    ) external override onlyCoordinator(gameId) {
        _requireSettlableModule();
        _submitDrawProof(gameId, player, newCommitment, newEncryptionKeyCommitment, newCiphertextRef, proof);
    }

    function _submitDrawProof(
        uint256 gameId,
        address player,
        bytes32 newCommitment,
        bytes32 newEncryptionKeyCommitment,
        bytes32 newCiphertextRef,
        bytes memory proof
    ) internal {
        Game storage game = games[gameId];
        require(game.matchState == MatchState.Active, "SingleDraw: inactive");
        require(game.hand.handPhase == uint8(HandPhase.DrawProofPending), "SingleDraw: no draw");

        uint256 actor = _playerIndex(game, player);
        require(game.hand.drawDeclared[actor], "SingleDraw: draw undeclared");
        require(!game.hand.drawResolved[actor], "SingleDraw: draw resolved");

        if (game.verifierBundle != address(0)) {
            IPokerVerifierBundle.DrawPublicInputs memory inputs = IPokerVerifierBundle.DrawPublicInputs({
                gameId: gameId,
                handNumber: game.hand.handNumber,
                handNonce: uint256(game.hand.handNonce),
                playerIndex: actor,
                deckCommitment: uint256(game.hand.deckCommitment),
                oldCommitment: uint256(game.hand.handCommitments[actor]),
                newCommitment: uint256(newCommitment),
                newEncryptionKeyCommitment: uint256(newEncryptionKeyCommitment),
                newCiphertextRef: uint256(newCiphertextRef),
                discardMask: game.hand.declaredDrawMasks[actor],
                proofSequence: game.hand.proofSequences[actor] + 1
            });
            require(
                IPokerVerifierBundle(game.verifierBundle).verifyDraw(proof, inputs), "SingleDraw: invalid draw proof"
            );
        }

        game.hand.handCommitments[actor] = newCommitment;
        game.hand.encryptionKeyCommitments[actor] = newEncryptionKeyCommitment;
        game.hand.ciphertextRefs[actor] = newCiphertextRef;
        game.hand.proofSequences[actor] += 1;
        game.hand.drawResolved[actor] = true;
        emit DrawResolved(gameId, player, newCommitment);

        if (game.hand.drawResolved[0] && game.hand.drawResolved[1]) {
            game.hand.handPhase = uint8(HandPhase.PostDrawBetting);
            game.players[0].hasActed = false;
            game.players[1].hasActed = false;
            game.players[0].currentBet = 0;
            game.players[1].currentBet = 0;
            game.highestBet = 0;
            game.currentTurn = 1 - game.dealerIdx;
            game.hand.expectedActor = uint8(game.currentTurn);
            game.hand.deadlineAt = block.timestamp + game.actionWindow;
        }
    }

    function submitShowdownProof(uint256 gameId, address winnerAddr, bool isTie, bytes calldata proof)
        external
        override
        onlyCoordinator(gameId)
    {
        _requireSettlableModule();

        Game storage game = games[gameId];
        require(game.matchState == MatchState.Active, "SingleDraw: inactive");
        require(game.hand.handPhase == uint8(HandPhase.ShowdownProofPending), "SingleDraw: no showdown");

        uint256 winnerIndex = isTie ? 2 : _playerIndex(game, winnerAddr);
        if (game.verifierBundle != address(0)) {
            IPokerVerifierBundle.ShowdownPublicInputs memory inputs = IPokerVerifierBundle.ShowdownPublicInputs({
                gameId: gameId,
                handNumber: game.hand.handNumber,
                handNonce: uint256(game.hand.handNonce),
                handCommitments: [uint256(game.hand.handCommitments[0]), uint256(game.hand.handCommitments[1])],
                winnerIndex: winnerIndex,
                isTie: isTie ? 1 : 0
            });
            require(
                IPokerVerifierBundle(game.verifierBundle).verifyShowdown(proof, inputs), "SingleDraw: invalid showdown"
            );
        }

        emit ShowdownSubmitted(gameId, msg.sender, winnerAddr, isTie);
        _completeHand(gameId, game, winnerAddr, isTie);
    }

    function claimTimeout(uint256 gameId) external override {
        _requireSettlableModule();

        Game storage game = games[gameId];
        require(_isPlayerClockPhase(game.hand.handPhase), "SingleDraw: no timeout");
        require(block.timestamp > game.hand.deadlineAt, "SingleDraw: active");
        _completeHand(gameId, game, game.players[1 - game.currentTurn].addr, false);
    }

    function handleTimeout(uint256 gameId, address player) external override onlyController(gameId) {
        _requireSettlableModule();

        Game storage game = games[gameId];
        require(_isPlayerClockPhase(game.hand.handPhase), "SingleDraw: no timeout");
        require(game.players[game.currentTurn].addr == player, "SingleDraw: wrong actor");
        require(block.timestamp > game.hand.deadlineAt, "SingleDraw: active");
        _completeHand(gameId, game, game.players[1 - game.currentTurn].addr, false);
    }

    function isGameOver(uint256 gameId) public view override returns (bool isOver) {
        return games[gameId].matchState == MatchState.Completed;
    }

    function getOutcomes(uint256 gameId)
        external
        view
        override
        returns (address[] memory winners, uint256[] memory payouts)
    {
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

    function _advanceAfterBettingAction(Game storage game, bool forcePostDraw) internal {
        if (
            game.players[0].hasActed && game.players[1].hasActed
                && game.players[0].currentBet == game.players[1].currentBet
        ) {
            game.players[0].currentBet = 0;
            game.players[1].currentBet = 0;
            game.players[0].hasActed = false;
            game.players[1].hasActed = false;
            game.highestBet = 0;

            if (!forcePostDraw && game.hand.handPhase == uint8(HandPhase.PreDrawBetting)) {
                game.hand.handPhase = uint8(HandPhase.DrawDeclaration);
                game.currentTurn = 1 - game.dealerIdx;
                game.hand.expectedActor = uint8(game.currentTurn);
                game.hand.deadlineAt = block.timestamp + game.actionWindow;
            } else {
                game.hand.handPhase = uint8(HandPhase.ShowdownProofPending);
                game.hand.expectedActor = COORDINATOR_ACTOR;
                game.hand.deadlineAt = 0;
            }
        } else {
            game.currentTurn = 1 - game.currentTurn;
            game.hand.expectedActor = uint8(game.currentTurn);
            game.hand.deadlineAt = block.timestamp + game.actionWindow;
        }
    }

    function _startNextHand(uint256 gameId, Game storage game) internal {
        game.hand.handPhase = uint8(HandPhase.AwaitingInitialDeal);
        game.hand.handNumber += 1;
        game.hand.deadlineAt = 0;
        game.hand.expectedActor = COORDINATOR_ACTOR;
        game.hand.deckCommitment = bytes32(0);
        game.hand.handNonce = bytes32(0);
        game.hand.handCommitments[0] = bytes32(0);
        game.hand.handCommitments[1] = bytes32(0);
        game.hand.encryptionKeyCommitments[0] = bytes32(0);
        game.hand.encryptionKeyCommitments[1] = bytes32(0);
        game.hand.ciphertextRefs[0] = bytes32(0);
        game.hand.ciphertextRefs[1] = bytes32(0);
        game.hand.proofSequences[0] = 0;
        game.hand.proofSequences[1] = 0;
        game.hand.drawResolved[0] = false;
        game.hand.drawResolved[1] = false;
        game.hand.drawDeclared[0] = false;
        game.hand.drawDeclared[1] = false;
        game.hand.declaredDrawMasks[0] = 0;
        game.hand.declaredDrawMasks[1] = 0;
        game.players[0].hasActed = false;
        game.players[1].hasActed = false;
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
        emit HandAwaitingInitialDeal(gameId, game.hand.handNumber);
    }

    function _completeHand(uint256 gameId, Game storage game, address winnerAddr, bool isTie) internal {
        if (isTie) {
            uint256 half = game.pot / 2;
            game.players[0].stack += half;
            game.players[1].stack += game.pot - half;
        } else {
            uint256 winnerIndex = _playerIndex(game, winnerAddr);
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
        _startNextHand(gameId, game);
    }

    function _playerIndex(Game storage game, address player) internal view returns (uint256) {
        if (game.players[0].addr == player) {
            return 0;
        }
        require(game.players[1].addr == player, "SingleDraw: not player");
        return 1;
    }

    function _drawMask(uint8[] calldata cardIndices) internal pure returns (uint8 discardMask) {
        require(cardIndices.length <= 5, "SingleDraw: too many");
        for (uint256 i = 0; i < cardIndices.length; i++) {
            require(cardIndices[i] < 5, "SingleDraw: bad draw index");
            uint8 bit = uint8(1 << cardIndices[i]);
            require(discardMask & bit == 0, "SingleDraw: duplicate draw index");
            discardMask |= bit;
        }
    }

    function _requireUnexpired(Game storage game) internal view {
        require(block.timestamp <= game.hand.deadlineAt, "SingleDraw: expired");
    }

    function _isPlayerClockPhase(uint8 phase) internal pure returns (bool) {
        return phase == uint8(HandPhase.PreDrawBetting) || phase == uint8(HandPhase.PostDrawBetting)
            || phase == uint8(HandPhase.DrawDeclaration);
    }

    function _requireSettlableModule() internal view {
        require(CATALOG.isSettlableEngine(address(this)), "SingleDraw: module inactive");
    }
}
