// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {GameCatalog} from "../GameCatalog.sol";
import {IBlackjackVerifierBundle} from "../interfaces/IBlackjackVerifierBundle.sol";
import {ISoloLifecycleEngine} from "../interfaces/ISoloLifecycleEngine.sol";

/// @title Single-deck blackjack engine
/// @notice Manages blackjack session state, player actions, coordinator proofs, and solo settlement outcomes.
contract SingleDeckBlackjackEngine is ISoloLifecycleEngine {
    bytes32 public constant ENGINE_TYPE = keccak256("BLACKJACK_SINGLE_DECK_ZK");
    uint8 public constant CARD_EMPTY = 52;

    uint8 public constant ACTION_HIT = 1;
    uint8 public constant ACTION_STAND = 2;
    uint8 public constant ACTION_DOUBLE = 3;
    uint8 public constant ACTION_SPLIT = 4;

    uint8 public constant ALLOW_HIT = 1;
    uint8 public constant ALLOW_STAND = 2;
    uint8 public constant ALLOW_DOUBLE = 4;
    uint8 public constant ALLOW_SPLIT = 8;

    uint8 public constant HAND_PAYOUT_NONE = 0;
    uint8 public constant HAND_PAYOUT_LOSS = 1;
    uint8 public constant HAND_PAYOUT_PUSH = 2;
    uint8 public constant HAND_PAYOUT_EVEN_MONEY = 3;
    uint8 public constant HAND_PAYOUT_BLACKJACK_3_TO_2 = 4;
    uint8 public constant HAND_PAYOUT_SUITED_BLACKJACK_2_TO_1 = 5;

    /// @notice Session lifecycle values exposed to clients as raw `uint8` data.
    enum SessionPhase {
        Inactive,
        AwaitingInitialDeal,
        AwaitingPlayerAction,
        AwaitingCoordinator,
        Completed
    }

    /// @notice Lightweight view of one blackjack hand within a session.
    struct HandView {
        uint256 wager;
        uint256 value;
        uint8 status;
        uint8 allowedActionMask;
        uint8 cardCount;
        uint8 payoutKind;
    }

    /// @notice Stored mutable session state.
    struct Session {
        address player;
        uint256 wager;
        uint256 totalBurned;
        bytes32 playRef;
        SessionPhase phase;
        uint256 actionWindow;
        uint256 deadlineAt;
        uint256 proofSequence;
        bytes32 deckCommitment;
        bytes32 handNonce;
        bytes32 playerStateCommitment;
        bytes32 dealerStateCommitment;
        bytes32 playerKeyCommitment;
        bytes32 playerCiphertextRef;
        bytes32 dealerCiphertextRef;
        uint256 dealerVisibleValue;
        uint8 handCount;
        uint8 activeHandIndex;
        uint8 pendingAction;
        uint8 immediateResultCode;
        uint256 payout;
        uint256 softMask;
        uint256 pendingAdditionalBurn;
        uint8 dealerRevealMask;
        HandView[4] hands;
        uint8[8] playerCards;
        uint8[4] dealerCards;
    }

    /// @notice Fully expanded read-only session snapshot returned by `getSession`.
    struct SessionView {
        address player;
        uint256 wager;
        uint256 totalBurned;
        bytes32 playRef;
        uint8 phase;
        uint256 actionWindow;
        uint256 deadlineAt;
        uint256 proofSequence;
        bytes32 deckCommitment;
        bytes32 handNonce;
        bytes32 playerStateCommitment;
        bytes32 dealerStateCommitment;
        bytes32 playerKeyCommitment;
        bytes32 playerCiphertextRef;
        bytes32 dealerCiphertextRef;
        uint256 dealerVisibleValue;
        uint8 handCount;
        uint8 activeHandIndex;
        uint8 pendingAction;
        uint8 immediateResultCode;
        uint256 payout;
        uint256 softMask;
        uint8 dealerRevealMask;
        HandView[4] hands;
        uint8[8] playerCards;
        uint8[4] dealerCards;
    }

    GameCatalog internal immutable CATALOG;
    address public immutable COORDINATOR;
    uint256 public immutable DEFAULT_ACTION_WINDOW;
    IBlackjackVerifierBundle public immutable VERIFIER_BUNDLE;
    uint256 public nextSessionId = 1;

    mapping(uint256 => Session) internal sessions;

    /// @notice Emitted when a new blackjack session is opened.
    event SessionOpened(uint256 indexed sessionId, address indexed player, uint256 wager, bytes32 playRef);
    /// @notice Emitted when the initial-deal proof resolves the first visible blackjack state.
    event InitialDealResolved(uint256 indexed sessionId, bytes32 deckCommitment, uint256 dealerVisibleValue);
    /// @notice Emitted when the controller records a player action and any extra burn.
    event ActionDeclared(uint256 indexed sessionId, address indexed player, uint8 indexed action, uint256 additionalBurn);
    /// @notice Emitted when an action proof advances the session state.
    event ActionResolved(uint256 indexed sessionId, uint8 indexed action, uint8 nextPhase);
    /// @notice Emitted when a player timeout is converted into a forced stand.
    event PlayerTimeoutClaimed(uint256 indexed sessionId);
    /// @notice Emitted when the showdown proof fixes the payout and completes the session.
    event ShowdownResolved(uint256 indexed sessionId, uint256 payout);

    /// @notice Initializes the engine with catalog, verifier, coordinator, and action-window config.
    constructor(address catalogAddress, address verifierBundleAddress, address coordinatorAddress, uint256 defaultActionWindow) {
        CATALOG = GameCatalog(catalogAddress);
        COORDINATOR = coordinatorAddress;
        DEFAULT_ACTION_WINDOW = defaultActionWindow;
        VERIFIER_BUNDLE = IBlackjackVerifierBundle(verifierBundleAddress);
    }

    /// @notice Returns the catalog used for controller authorization and lifecycle gating.
    function catalog() public view returns (GameCatalog) {
        return CATALOG;
    }

    /// @notice Returns the engine type tag for blackjack sessions.
    function engineType() external pure returns (bytes32) {
        return ENGINE_TYPE;
    }

    /// @notice Opens a new blackjack session on behalf of an authorized controller.
    function openSession(address player, uint256 wager, bytes32 playRef, bytes32 playerKeyCommitment)
        external
        returns (uint256 sessionId)
    {
        _requireAuthorizedController();

        sessionId = nextSessionId++;
        Session storage session = sessions[sessionId];
        session.player = player;
        session.wager = wager;
        session.totalBurned = wager;
        session.playRef = playRef;
        session.phase = SessionPhase.AwaitingInitialDeal;
        session.actionWindow = DEFAULT_ACTION_WINDOW;
        session.playerKeyCommitment = playerKeyCommitment;
        session.handCount = 1;
        session.hands[0].wager = wager;
        for (uint256 i = 0; i < 8; i++) {
            session.playerCards[i] = CARD_EMPTY;
        }
        for (uint256 i = 0; i < 4; i++) {
            session.dealerCards[i] = CARD_EMPTY;
        }
        emit SessionOpened(sessionId, player, wager, playRef);
    }

    /// @notice Applies the initial-deal proof and transitions the session into player or completed state.
    function submitInitialDealProof(
        uint256 sessionId,
        bytes32 deckCommitment,
        bytes32 handNonce,
        bytes32 playerStateCommitment,
        bytes32 dealerStateCommitment,
        bytes32 playerCiphertextRef,
        bytes32 dealerCiphertextRef,
        uint256 dealerVisibleValue,
        uint8[8] calldata playerCards,
        uint8[4] calldata dealerCards,
        uint8 handCount,
        uint8 activeHandIndex,
        uint256 payout,
        uint8 immediateResultCode,
        uint256[4] calldata handValues,
        uint8[4] calldata handStatuses,
        uint8[4] calldata allowedActionMasks,
        uint8[4] calldata handCardCounts,
        uint8[4] calldata handPayoutKinds,
        uint8 dealerRevealMask,
        uint256 softMask,
        bytes calldata proof
    ) external {
        _requireSettlableModule();
        _requireCoordinator();

        Session storage session = sessions[sessionId];
        require(session.phase == SessionPhase.AwaitingInitialDeal, "Blackjack: bad init phase");
        require(session.handCount == 1, "Blackjack: session initialized");

        IBlackjackVerifierBundle.InitialDealPublicInputs memory inputs = IBlackjackVerifierBundle.InitialDealPublicInputs({
            sessionId: sessionId,
            handNonce: uint256(handNonce),
            deckCommitment: uint256(deckCommitment),
            playerStateCommitment: uint256(playerStateCommitment),
            dealerStateCommitment: uint256(dealerStateCommitment),
            playerKeyCommitment: uint256(session.playerKeyCommitment),
            playerCiphertextRef: uint256(playerCiphertextRef),
            dealerCiphertextRef: uint256(dealerCiphertextRef),
            dealerUpValue: dealerVisibleValue,
            baseWager: session.hands[0].wager,
            handCount: handCount,
            activeHandIndex: activeHandIndex,
            payout: payout,
            immediateResultCode: immediateResultCode,
            handValues: handValues,
            softMask: softMask,
            handStatuses: [uint256(handStatuses[0]), uint256(handStatuses[1]), uint256(handStatuses[2]), uint256(handStatuses[3])],
            allowedActionMasks: [
                uint256(allowedActionMasks[0]),
                uint256(allowedActionMasks[1]),
                uint256(allowedActionMasks[2]),
                uint256(allowedActionMasks[3])
            ],
            handCardCounts: [
                uint256(handCardCounts[0]),
                uint256(handCardCounts[1]),
                uint256(handCardCounts[2]),
                uint256(handCardCounts[3])
            ],
            handPayoutKinds: [
                uint256(handPayoutKinds[0]),
                uint256(handPayoutKinds[1]),
                uint256(handPayoutKinds[2]),
                uint256(handPayoutKinds[3])
            ],
            playerCards: [
                uint256(playerCards[0]),
                uint256(playerCards[1]),
                uint256(playerCards[2]),
                uint256(playerCards[3]),
                uint256(playerCards[4]),
                uint256(playerCards[5]),
                uint256(playerCards[6]),
                uint256(playerCards[7])
            ],
            dealerCards: [
                uint256(dealerCards[0]),
                uint256(dealerCards[1]),
                uint256(dealerCards[2]),
                uint256(dealerCards[3])
            ],
            dealerRevealMask: dealerRevealMask
        });
        require(VERIFIER_BUNDLE.verifyInitialDeal(proof, inputs), "Blackjack: invalid init proof");

        session.deckCommitment = deckCommitment;
        session.handNonce = handNonce;
        session.playerStateCommitment = playerStateCommitment;
        session.dealerStateCommitment = dealerStateCommitment;
        session.playerCiphertextRef = playerCiphertextRef;
        session.dealerCiphertextRef = dealerCiphertextRef;
        session.dealerVisibleValue = dealerVisibleValue;
        session.handCount = handCount;
        session.activeHandIndex = activeHandIndex;
        session.payout = payout;
        session.immediateResultCode = immediateResultCode;
        session.softMask = softMask;
        session.dealerRevealMask = dealerRevealMask;
        for (uint256 i = 0; i < 4; i++) {
            session.hands[i].value = handValues[i];
            session.hands[i].status = handStatuses[i];
            session.hands[i].allowedActionMask = allowedActionMasks[i];
            session.hands[i].cardCount = handCardCounts[i];
            session.hands[i].payoutKind = handPayoutKinds[i];
            session.dealerCards[i] = dealerCards[i];
        }
        for (uint256 i = 0; i < 8; i++) {
            session.playerCards[i] = playerCards[i];
        }

        if (payout > 0 || immediateResultCode != 0) {
            session.phase = SessionPhase.Completed;
        } else {
            session.phase = SessionPhase.AwaitingPlayerAction;
            session.deadlineAt = block.timestamp + session.actionWindow;
        }
        emit InitialDealResolved(sessionId, deckCommitment, dealerVisibleValue);
    }

    /// @notice Returns the extra burn required for a pending double-down or split action.
    function requiredAdditionalBurn(uint256 sessionId, uint8 action) public view returns (uint256 additionalBurn) {
        Session storage session = sessions[sessionId];
        if (session.phase != SessionPhase.AwaitingPlayerAction || session.pendingAction != 0) {
            return 0;
        }

        HandView storage hand = session.hands[session.activeHandIndex];
        if (action == ACTION_DOUBLE && hand.allowedActionMask & ALLOW_DOUBLE != 0) {
            return hand.wager;
        }
        if (action == ACTION_SPLIT && hand.allowedActionMask & ALLOW_SPLIT != 0 && session.handCount < 4) {
            return hand.wager;
        }
        return 0;
    }

    /// @notice Records a validated player action on behalf of the controller.
    function declareAction(uint256 sessionId, address player, uint8 action, uint256 additionalBurn) external {
        _requireAuthorizedController();

        Session storage session = sessions[sessionId];
        require(session.phase == SessionPhase.AwaitingPlayerAction, "Blackjack: no player action");
        require(session.player == player, "Blackjack: not player");
        require(block.timestamp <= session.deadlineAt, "Blackjack: expired");
        require(session.pendingAction == 0, "Blackjack: pending action");

        HandView storage hand = session.hands[session.activeHandIndex];
        uint8 flag = _actionFlag(action);
        require(hand.allowedActionMask & flag != 0, "Blackjack: action disallowed");

        uint256 expectedBurn = requiredAdditionalBurn(sessionId, action);
        require(additionalBurn == expectedBurn, "Blackjack: bad additional burn");

        session.totalBurned += additionalBurn;
        session.pendingAdditionalBurn = additionalBurn;
        session.pendingAction = action;
        session.phase = SessionPhase.AwaitingCoordinator;
        session.deadlineAt = 0;
        emit ActionDeclared(sessionId, player, action, additionalBurn);
    }

    /// @notice Converts an expired player-clock step into a forced stand.
    function claimPlayerTimeout(uint256 sessionId) external {
        _requireAuthorizedController();

        Session storage session = sessions[sessionId];
        require(session.phase == SessionPhase.AwaitingPlayerAction, "Blackjack: no timeout");
        require(block.timestamp > session.deadlineAt, "Blackjack: active");
        require(session.pendingAction == 0, "Blackjack: pending action");

        session.pendingAction = ACTION_STAND;
        session.pendingAdditionalBurn = 0;
        session.phase = SessionPhase.AwaitingCoordinator;
        session.deadlineAt = 0;
        emit PlayerTimeoutClaimed(sessionId);
    }

    /// @notice Applies a coordinator action proof and advances the session state.
    function submitActionProof(
        uint256 sessionId,
        bytes32 newPlayerStateCommitment,
        bytes32 dealerStateCommitment,
        bytes32 playerCiphertextRef,
        bytes32 dealerCiphertextRef,
        uint256 dealerVisibleValue,
        uint8[8] calldata playerCards,
        uint8[4] calldata dealerCards,
        uint8 handCount,
        uint8 activeHandIndex,
        uint8 nextPhase,
        uint256[4] calldata handValues,
        uint8[4] calldata handStatuses,
        uint8[4] calldata allowedActionMasks,
        uint8[4] calldata handCardCounts,
        uint8[4] calldata handPayoutKinds,
        uint8 dealerRevealMask,
        uint256 softMask,
        bytes calldata proof
    ) external {
        _requireSettlableModule();
        _requireCoordinator();

        Session storage session = sessions[sessionId];
        require(session.phase == SessionPhase.AwaitingCoordinator, "Blackjack: no coordinator action");
        require(session.pendingAction != 0, "Blackjack: no pending action");

        IBlackjackVerifierBundle.ActionPublicInputs memory inputs = IBlackjackVerifierBundle.ActionPublicInputs({
            sessionId: sessionId,
            proofSequence: session.proofSequence + 1,
            pendingAction: session.pendingAction,
            oldPlayerStateCommitment: uint256(session.playerStateCommitment),
            newPlayerStateCommitment: uint256(newPlayerStateCommitment),
            dealerStateCommitment: uint256(dealerStateCommitment),
            playerKeyCommitment: uint256(session.playerKeyCommitment),
            playerCiphertextRef: uint256(playerCiphertextRef),
            dealerCiphertextRef: uint256(dealerCiphertextRef),
            dealerUpValue: dealerVisibleValue,
            handCount: handCount,
            activeHandIndex: activeHandIndex,
            nextPhase: nextPhase,
            handValues: handValues,
            softMask: softMask,
            handStatuses: [uint256(handStatuses[0]), uint256(handStatuses[1]), uint256(handStatuses[2]), uint256(handStatuses[3])],
            allowedActionMasks: [
                uint256(allowedActionMasks[0]),
                uint256(allowedActionMasks[1]),
                uint256(allowedActionMasks[2]),
                uint256(allowedActionMasks[3])
            ],
            handCardCounts: [
                uint256(handCardCounts[0]),
                uint256(handCardCounts[1]),
                uint256(handCardCounts[2]),
                uint256(handCardCounts[3])
            ],
            handPayoutKinds: [
                uint256(handPayoutKinds[0]),
                uint256(handPayoutKinds[1]),
                uint256(handPayoutKinds[2]),
                uint256(handPayoutKinds[3])
            ],
            playerCards: [
                uint256(playerCards[0]),
                uint256(playerCards[1]),
                uint256(playerCards[2]),
                uint256(playerCards[3]),
                uint256(playerCards[4]),
                uint256(playerCards[5]),
                uint256(playerCards[6]),
                uint256(playerCards[7])
            ],
            dealerCards: [
                uint256(dealerCards[0]),
                uint256(dealerCards[1]),
                uint256(dealerCards[2]),
                uint256(dealerCards[3])
            ],
            dealerRevealMask: dealerRevealMask
        });
        require(VERIFIER_BUNDLE.verifyAction(proof, inputs), "Blackjack: invalid action proof");

        _applyPendingBurnEffects(session);

        session.proofSequence += 1;
        session.playerStateCommitment = newPlayerStateCommitment;
        session.dealerStateCommitment = dealerStateCommitment;
        session.playerCiphertextRef = playerCiphertextRef;
        session.dealerCiphertextRef = dealerCiphertextRef;
        session.dealerVisibleValue = dealerVisibleValue;
        session.handCount = handCount;
        session.activeHandIndex = activeHandIndex;
        session.softMask = softMask;
        session.dealerRevealMask = dealerRevealMask;
        for (uint256 i = 0; i < 4; i++) {
            session.hands[i].value = handValues[i];
            session.hands[i].status = handStatuses[i];
            session.hands[i].allowedActionMask = allowedActionMasks[i];
            session.hands[i].cardCount = handCardCounts[i];
            session.hands[i].payoutKind = handPayoutKinds[i];
            session.dealerCards[i] = dealerCards[i];
        }
        for (uint256 i = 0; i < 8; i++) {
            session.playerCards[i] = playerCards[i];
        }

        session.pendingAction = 0;
        session.pendingAdditionalBurn = 0;
        session.phase = SessionPhase(nextPhase);
        session.deadlineAt = nextPhase == uint8(SessionPhase.AwaitingPlayerAction)
            ? block.timestamp + session.actionWindow
            : 0;

        emit ActionResolved(sessionId, uint8(inputs.pendingAction), nextPhase);
    }

    /// @notice Applies the final showdown proof and marks the session completed.
    function submitShowdownProof(
        uint256 sessionId,
        bytes32 playerStateCommitment,
        bytes32 dealerStateCommitment,
        uint256 payout,
        uint256 dealerFinalValue,
        uint8[8] calldata playerCards,
        uint8[4] calldata dealerCards,
        uint8 handCount,
        uint8 activeHandIndex,
        uint8[4] calldata handStatuses,
        uint256[4] calldata handValues,
        uint8[4] calldata handCardCounts,
        uint8[4] calldata handPayoutKinds,
        uint8 dealerRevealMask,
        bytes calldata proof
    ) external {
        _requireSettlableModule();
        _requireCoordinator();

        Session storage session = sessions[sessionId];
        require(session.phase == SessionPhase.AwaitingCoordinator, "Blackjack: no showdown");
        require(session.pendingAction == 0 || session.pendingAction == ACTION_STAND, "Blackjack: showdown blocked");

        IBlackjackVerifierBundle.ShowdownPublicInputs memory inputs = IBlackjackVerifierBundle.ShowdownPublicInputs({
            sessionId: sessionId,
            proofSequence: session.proofSequence + 1,
            playerStateCommitment: uint256(playerStateCommitment),
            dealerStateCommitment: uint256(dealerStateCommitment),
            payout: payout,
            dealerFinalValue: dealerFinalValue,
            handCount: handCount,
            activeHandIndex: activeHandIndex,
            handStatuses: [uint256(handStatuses[0]), uint256(handStatuses[1]), uint256(handStatuses[2]), uint256(handStatuses[3])],
            handValues: handValues,
            handWagers: [
                session.hands[0].wager,
                session.hands[1].wager,
                session.hands[2].wager,
                session.hands[3].wager
            ],
            handCardCounts: [
                uint256(handCardCounts[0]),
                uint256(handCardCounts[1]),
                uint256(handCardCounts[2]),
                uint256(handCardCounts[3])
            ],
            handPayoutKinds: [
                uint256(handPayoutKinds[0]),
                uint256(handPayoutKinds[1]),
                uint256(handPayoutKinds[2]),
                uint256(handPayoutKinds[3])
            ],
            playerCards: [
                uint256(playerCards[0]),
                uint256(playerCards[1]),
                uint256(playerCards[2]),
                uint256(playerCards[3]),
                uint256(playerCards[4]),
                uint256(playerCards[5]),
                uint256(playerCards[6]),
                uint256(playerCards[7])
            ],
            dealerCards: [
                uint256(dealerCards[0]),
                uint256(dealerCards[1]),
                uint256(dealerCards[2]),
                uint256(dealerCards[3])
            ],
            dealerRevealMask: dealerRevealMask
        });
        require(VERIFIER_BUNDLE.verifyShowdown(proof, inputs), "Blackjack: invalid showdown proof");

        session.proofSequence += 1;
        session.playerStateCommitment = playerStateCommitment;
        session.dealerStateCommitment = dealerStateCommitment;
        session.payout = payout;
        session.dealerVisibleValue = dealerFinalValue;
        session.handCount = handCount;
        session.activeHandIndex = activeHandIndex;
        session.dealerRevealMask = dealerRevealMask;
        for (uint256 i = 0; i < 4; i++) {
            session.hands[i].value = handValues[i];
            session.hands[i].status = handStatuses[i];
            session.hands[i].allowedActionMask = 0;
            session.hands[i].cardCount = handCardCounts[i];
            session.hands[i].payoutKind = handPayoutKinds[i];
            session.dealerCards[i] = dealerCards[i];
        }
        for (uint256 i = 0; i < 8; i++) {
            session.playerCards[i] = playerCards[i];
        }
        session.pendingAction = 0;
        session.pendingAdditionalBurn = 0;
        session.phase = SessionPhase.Completed;
        session.deadlineAt = 0;

        emit ShowdownResolved(sessionId, payout);
    }

    /// @notice Returns a fully expanded session snapshot for client reads.
    function getSession(uint256 sessionId) external view returns (SessionView memory viewState) {
        Session storage session = sessions[sessionId];
        viewState.player = session.player;
        viewState.wager = session.wager;
        viewState.totalBurned = session.totalBurned;
        viewState.playRef = session.playRef;
        viewState.phase = uint8(session.phase);
        viewState.actionWindow = session.actionWindow;
        viewState.deadlineAt = session.deadlineAt;
        viewState.proofSequence = session.proofSequence;
        viewState.deckCommitment = session.deckCommitment;
        viewState.handNonce = session.handNonce;
        viewState.playerStateCommitment = session.playerStateCommitment;
        viewState.dealerStateCommitment = session.dealerStateCommitment;
        viewState.playerKeyCommitment = session.playerKeyCommitment;
        viewState.playerCiphertextRef = session.playerCiphertextRef;
        viewState.dealerCiphertextRef = session.dealerCiphertextRef;
        viewState.dealerVisibleValue = session.dealerVisibleValue;
        viewState.handCount = session.handCount;
        viewState.activeHandIndex = session.activeHandIndex;
        viewState.pendingAction = session.pendingAction;
        viewState.immediateResultCode = session.immediateResultCode;
        viewState.payout = session.payout;
        viewState.softMask = session.softMask;
        viewState.dealerRevealMask = session.dealerRevealMask;
        for (uint256 i = 0; i < 4; i++) {
            viewState.hands[i] = session.hands[i];
            viewState.dealerCards[i] = session.dealerCards[i];
        }
        for (uint256 i = 0; i < 8; i++) {
            viewState.playerCards[i] = session.playerCards[i];
        }
    }

    /// @notice Returns the normalized solo-settlement tuple for a session id.
    function getSettlementOutcome(uint256 sessionId)
        external
        view
        returns (address player, uint256 totalBurned, uint256 payout, bool completed)
    {
        Session storage session = sessions[sessionId];
        return (session.player, session.totalBurned, session.payout, session.phase == SessionPhase.Completed);
    }

    function _applyPendingBurnEffects(Session storage session) internal {
        if (session.pendingAction == ACTION_DOUBLE && session.pendingAdditionalBurn > 0) {
            session.hands[session.activeHandIndex].wager += session.pendingAdditionalBurn;
        }
        if (session.pendingAction == ACTION_SPLIT && session.pendingAdditionalBurn > 0) {
            uint8 newIndex = session.handCount;
            if (newIndex < 4) {
                session.hands[newIndex].wager = session.hands[session.activeHandIndex].wager;
            }
        }
    }

    function _actionFlag(uint8 action) internal pure returns (uint8) {
        if (action == ACTION_HIT) return ALLOW_HIT;
        if (action == ACTION_STAND) return ALLOW_STAND;
        if (action == ACTION_DOUBLE) return ALLOW_DOUBLE;
        if (action == ACTION_SPLIT) return ALLOW_SPLIT;
        revert("Blackjack: bad action");
    }

    function _requireAuthorizedController() internal view {
        require(CATALOG.isAuthorizedControllerForEngine(msg.sender, address(this)), "Blackjack: not controller");
    }

    function _requireCoordinator() internal view {
        require(msg.sender == COORDINATOR, "Blackjack: not coordinator");
    }

    function _requireSettlableModule() internal view {
        require(CATALOG.isSettlableEngine(address(this)), "Blackjack: module inactive");
    }
}
