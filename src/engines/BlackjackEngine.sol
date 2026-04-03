// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {GameCatalog} from "../GameCatalog.sol";
import {IBlackjackVerifierBundle} from "../interfaces/IBlackjackVerifierBundle.sol";
import {ISoloLifecycleEngine} from "../interfaces/ISoloLifecycleEngine.sol";

/// @title Blackjack engine
/// @notice Manages canonical double-deck blackjack session state, proof-gated transitions, and solo settlement.
contract BlackjackEngine is ISoloLifecycleEngine {
    bytes32 public constant ENGINE_TYPE = keccak256("BLACKJACK_ZK");
    uint256 internal constant MAX_PLAYER_CARDS = 32;
    uint256 internal constant MAX_DEALER_CARDS = 12;

    uint8 public constant CARD_EMPTY = 104;

    uint8 public constant ACTION_HIT = 1;
    uint8 public constant ACTION_STAND = 2;
    uint8 public constant ACTION_DOUBLE = 3;
    uint8 public constant ACTION_SPLIT = 4;

    uint8 public constant ALLOW_HIT = 1;
    uint8 public constant ALLOW_STAND = 2;
    uint8 public constant ALLOW_DOUBLE = 4;
    uint8 public constant ALLOW_SPLIT = 8;

    uint8 public constant HAND_STATUS_NONE = 0;
    uint8 public constant HAND_STATUS_ACTIVE = 1;
    uint8 public constant HAND_STATUS_STAND = 2;
    uint8 public constant HAND_STATUS_BUST = 3;
    uint8 public constant HAND_STATUS_PUSH = 4;
    uint8 public constant HAND_STATUS_WIN = 5;
    uint8 public constant HAND_STATUS_LOSS = 6;
    uint8 public constant HAND_STATUS_BLACKJACK = 7;
    uint8 public constant HAND_STATUS_SURRENDERED = 8;

    uint8 public constant HAND_PAYOUT_NONE = 0;
    uint8 public constant HAND_PAYOUT_LOSS = 1;
    uint8 public constant HAND_PAYOUT_PUSH = 2;
    uint8 public constant HAND_PAYOUT_EVEN_MONEY = 3;
    uint8 public constant HAND_PAYOUT_BLACKJACK_3_TO_2 = 4;
    uint8 public constant HAND_PAYOUT_SURRENDER = 5;

    uint8 public constant DECISION_NONE = 0;
    uint8 public constant DECISION_INSURANCE = 1;
    uint8 public constant DECISION_EARLY_SURRENDER = 2;
    uint8 public constant DECISION_LATE_SURRENDER = 3;

    uint8 public constant INSURANCE_NONE = 0;
    uint8 public constant INSURANCE_AVAILABLE = 1;
    uint8 public constant INSURANCE_DECLINED = 2;
    uint8 public constant INSURANCE_TAKEN = 3;
    uint8 public constant INSURANCE_LOST = 4;
    uint8 public constant INSURANCE_WON = 5;

    uint8 public constant SURRENDER_NONE = 0;
    uint8 public constant SURRENDER_AVAILABLE = 1;
    uint8 public constant SURRENDER_DECLINED = 2;
    uint8 public constant SURRENDER_TAKEN = 3;
    uint8 public constant SURRENDER_VOID = 4;

    /// @notice Session lifecycle values exposed to clients as raw `uint8` data.
    enum SessionPhase {
        Inactive,
        AwaitingInitialDeal,
        AwaitingPrePlayDecision,
        AwaitingPeekResolution,
        AwaitingPostPeekDecision,
        AwaitingPlayerAction,
        AwaitingCoordinatorAction,
        Completed
    }

    /// @notice Canonical per-hand read model exposed to clients.
    struct HandView {
        uint256 wager;
        uint256 value;
        uint8 status;
        uint8 allowedActionMask;
        uint8 cardCount;
        uint8 cardStartIndex;
        uint8 payoutKind;
    }

    /// @notice Proof-backed visible session state submitted by the coordinator.
    struct PublicSessionState {
        uint8 phase;
        uint8 decisionType;
        uint8 dealerRevealMask;
        uint8 handCount;
        uint8 activeHandIndex;
        uint8 peekAvailable;
        uint8 peekResolved;
        uint8 dealerHasBlackjack;
        uint8 insuranceAvailable;
        uint8 insuranceStatus;
        uint8 surrenderAvailable;
        uint8 surrenderStatus;
        uint256 dealerUpValue;
        uint256 dealerFinalValue;
        uint256 payout;
        uint256 insuranceStake;
        uint256 insurancePayout;
        HandView[4] hands;
        uint8[] playerCards;
        uint8[] dealerCards;
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
        uint8 pendingAction;
        uint8 decisionType;
        uint8 dealerRevealMask;
        uint8 handCount;
        uint8 activeHandIndex;
        uint8 peekAvailable;
        uint8 peekResolved;
        uint8 dealerHasBlackjack;
        uint8 insuranceAvailable;
        uint8 insuranceStatus;
        uint8 surrenderAvailable;
        uint8 surrenderStatus;
        uint256 dealerUpValue;
        uint256 dealerFinalValue;
        uint256 payout;
        uint256 insuranceStake;
        uint256 insurancePayout;
        uint256 pendingAdditionalBurn;
        HandView[4] hands;
        uint8[] playerCards;
        uint8[] dealerCards;
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
        uint8 pendingAction;
        uint8 decisionType;
        uint8 dealerRevealMask;
        uint8 handCount;
        uint8 activeHandIndex;
        uint8 peekAvailable;
        uint8 peekResolved;
        uint8 dealerHasBlackjack;
        uint8 insuranceAvailable;
        uint8 insuranceStatus;
        uint8 surrenderAvailable;
        uint8 surrenderStatus;
        uint256 dealerUpValue;
        uint256 dealerFinalValue;
        uint256 payout;
        uint256 insuranceStake;
        uint256 insurancePayout;
        HandView[4] hands;
        uint8[] playerCards;
        uint8[] dealerCards;
    }

    GameCatalog internal immutable CATALOG;
    address public immutable COORDINATOR;
    uint256 public immutable DEFAULT_ACTION_WINDOW;
    IBlackjackVerifierBundle public immutable VERIFIER_BUNDLE;
    uint256 public nextSessionId = 1;

    mapping(uint256 => Session) internal sessions;

    event SessionOpened(uint256 indexed sessionId, address indexed player, uint256 wager, bytes32 playRef);
    event InitialDealResolved(uint256 indexed sessionId, uint8 indexed phase, uint256 dealerUpValue);
    event PeekResolved(uint256 indexed sessionId, uint8 indexed phase, uint8 dealerHasBlackjack);
    event InsuranceDeclared(uint256 indexed sessionId, address indexed player, uint256 amount);
    event SurrenderResolved(uint256 indexed sessionId, address indexed player, uint256 payout);
    event ContinueDeclared(uint256 indexed sessionId, address indexed player, uint8 indexed phase);
    event ActionDeclared(
        uint256 indexed sessionId, address indexed player, uint8 indexed action, uint256 additionalBurn
    );
    event ActionResolved(uint256 indexed sessionId, uint8 indexed action, uint8 nextPhase);
    event PlayerTimeoutClaimed(uint256 indexed sessionId, uint8 indexed phase);
    event ShowdownResolved(uint256 indexed sessionId, uint256 payout);

    constructor(
        address catalogAddress,
        address verifierBundleAddress,
        address coordinatorAddress,
        uint256 defaultActionWindow
    ) {
        CATALOG = GameCatalog(catalogAddress);
        COORDINATOR = coordinatorAddress;
        DEFAULT_ACTION_WINDOW = defaultActionWindow;
        VERIFIER_BUNDLE = IBlackjackVerifierBundle(verifierBundleAddress);
    }

    function catalog() public view returns (GameCatalog) {
        return CATALOG;
    }

    function engineType() external pure returns (bytes32) {
        return ENGINE_TYPE;
    }

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
        emit SessionOpened(sessionId, player, wager, playRef);
    }

    function submitInitialDealProof(
        uint256 sessionId,
        bytes32 deckCommitment,
        bytes32 handNonce,
        bytes32 playerStateCommitment,
        bytes32 dealerStateCommitment,
        bytes32 playerCiphertextRef,
        bytes32 dealerCiphertextRef,
        PublicSessionState calldata publicState,
        bytes calldata proof
    ) external {
        _requireSettlableModule();
        _requireCoordinator();

        Session storage session = sessions[sessionId];
        require(session.phase == SessionPhase.AwaitingInitialDeal, "Blackjack: bad init phase");
        require(session.handCount == 1, "Blackjack: session initialized");

        IBlackjackVerifierBundle.InitialDealPublicInputs memory inputs =
            _buildInitialDealInputs(sessionId, session, deckCommitment, handNonce, playerStateCommitment, dealerStateCommitment, playerCiphertextRef, dealerCiphertextRef, publicState);
        require(VERIFIER_BUNDLE.verifyInitialDeal(proof, inputs), "Blackjack: invalid init proof");

        session.proofSequence = 1;
        session.deckCommitment = deckCommitment;
        session.handNonce = handNonce;
        session.playerStateCommitment = playerStateCommitment;
        session.dealerStateCommitment = dealerStateCommitment;
        session.playerCiphertextRef = playerCiphertextRef;
        session.dealerCiphertextRef = dealerCiphertextRef;
        _applyPublicState(session, publicState);

        emit InitialDealResolved(sessionId, publicState.phase, publicState.dealerUpValue);
    }

    function submitPeekProof(
        uint256 sessionId,
        bytes32 playerStateCommitment,
        bytes32 dealerStateCommitment,
        bytes32 playerCiphertextRef,
        bytes32 dealerCiphertextRef,
        PublicSessionState calldata publicState,
        bytes calldata proof
    ) external {
        _requireSettlableModule();
        _requireCoordinator();

        Session storage session = sessions[sessionId];
        require(session.phase == SessionPhase.AwaitingPeekResolution, "Blackjack: no peek");

        IBlackjackVerifierBundle.PeekPublicInputs memory inputs = _buildPeekInputs(
            sessionId,
            session,
            playerStateCommitment,
            dealerStateCommitment,
            playerCiphertextRef,
            dealerCiphertextRef,
            publicState
        );
        require(VERIFIER_BUNDLE.verifyPeek(proof, inputs), "Blackjack: invalid peek proof");

        session.proofSequence += 1;
        session.playerStateCommitment = playerStateCommitment;
        session.dealerStateCommitment = dealerStateCommitment;
        session.playerCiphertextRef = playerCiphertextRef;
        session.dealerCiphertextRef = dealerCiphertextRef;
        _applyPublicState(session, publicState);

        emit PeekResolved(sessionId, publicState.phase, publicState.dealerHasBlackjack);
    }

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

    function maxInsuranceStake(uint256 sessionId) public view returns (uint256) {
        Session storage session = sessions[sessionId];
        if (session.phase != SessionPhase.AwaitingPrePlayDecision || session.decisionType != DECISION_INSURANCE) {
            return 0;
        }
        return session.wager / 2;
    }

    function declareInsurance(uint256 sessionId, address player, uint256 amount) external {
        _requireAuthorizedController();

        Session storage session = sessions[sessionId];
        require(session.phase == SessionPhase.AwaitingPrePlayDecision, "Blackjack: no insurance");
        require(session.decisionType == DECISION_INSURANCE, "Blackjack: wrong decision");
        require(session.player == player, "Blackjack: not player");
        require(block.timestamp <= session.deadlineAt, "Blackjack: expired");
        require(amount > 0 && amount <= maxInsuranceStake(sessionId), "Blackjack: bad insurance");

        session.totalBurned += amount;
        session.insuranceStake = amount;
        session.insuranceStatus = INSURANCE_TAKEN;
        session.insuranceAvailable = 0;
        session.phase = SessionPhase.AwaitingPeekResolution;
        session.deadlineAt = 0;

        emit InsuranceDeclared(sessionId, player, amount);
    }

    function surrender(uint256 sessionId, address player) external {
        _requireAuthorizedController();

        Session storage session = sessions[sessionId];
        require(session.player == player, "Blackjack: not player");
        require(
            session.phase == SessionPhase.AwaitingPrePlayDecision || session.phase == SessionPhase.AwaitingPostPeekDecision,
            "Blackjack: no surrender"
        );
        require(block.timestamp <= session.deadlineAt, "Blackjack: expired");
        require(session.surrenderAvailable != 0, "Blackjack: surrender unavailable");
        require(session.dealerHasBlackjack == 0, "Blackjack: surrender void");

        HandView storage hand = session.hands[session.activeHandIndex];
        uint256 surrenderPayout = hand.wager / 2;

        hand.status = HAND_STATUS_SURRENDERED;
        hand.allowedActionMask = 0;
        hand.payoutKind = HAND_PAYOUT_SURRENDER;
        session.surrenderAvailable = 0;
        session.surrenderStatus = SURRENDER_TAKEN;
        session.decisionType = DECISION_NONE;
        session.payout = surrenderPayout + session.insurancePayout;
        session.phase = SessionPhase.Completed;
        session.deadlineAt = 0;

        emit SurrenderResolved(sessionId, player, session.payout);
    }

    function continuePlay(uint256 sessionId, address player) external {
        _requireAuthorizedController();

        Session storage session = sessions[sessionId];
        require(session.player == player, "Blackjack: not player");
        require(
            session.phase == SessionPhase.AwaitingPrePlayDecision || session.phase == SessionPhase.AwaitingPostPeekDecision,
            "Blackjack: no decision"
        );
        require(block.timestamp <= session.deadlineAt, "Blackjack: expired");

        _advanceDecisionWindow(session, false);
        emit ContinueDeclared(sessionId, player, uint8(session.phase));
    }

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
        session.phase = SessionPhase.AwaitingCoordinatorAction;
        session.deadlineAt = 0;
        emit ActionDeclared(sessionId, player, action, additionalBurn);
    }

    function claimPlayerTimeout(uint256 sessionId) external {
        _requireAuthorizedController();

        Session storage session = sessions[sessionId];
        require(
            session.phase == SessionPhase.AwaitingPrePlayDecision
                || session.phase == SessionPhase.AwaitingPostPeekDecision
                || session.phase == SessionPhase.AwaitingPlayerAction,
            "Blackjack: no timeout"
        );
        require(block.timestamp > session.deadlineAt, "Blackjack: active");

        if (session.phase == SessionPhase.AwaitingPlayerAction) {
            require(session.pendingAction == 0, "Blackjack: pending action");
            session.pendingAction = ACTION_STAND;
            session.pendingAdditionalBurn = 0;
            session.phase = SessionPhase.AwaitingCoordinatorAction;
            session.deadlineAt = 0;
        } else {
            _advanceDecisionWindow(session, true);
        }

        emit PlayerTimeoutClaimed(sessionId, uint8(session.phase));
    }

    function submitActionProof(
        uint256 sessionId,
        bytes32 newPlayerStateCommitment,
        bytes32 dealerStateCommitment,
        bytes32 playerCiphertextRef,
        bytes32 dealerCiphertextRef,
        PublicSessionState calldata publicState,
        bytes calldata proof
    ) external {
        _requireSettlableModule();
        _requireCoordinator();

        Session storage session = sessions[sessionId];
        require(session.phase == SessionPhase.AwaitingCoordinatorAction, "Blackjack: no coordinator action");
        require(session.pendingAction != 0, "Blackjack: no pending action");

        IBlackjackVerifierBundle.ActionPublicInputs memory inputs = _buildActionInputs(
            sessionId,
            session,
            newPlayerStateCommitment,
            dealerStateCommitment,
            playerCiphertextRef,
            dealerCiphertextRef,
            publicState
        );
        require(VERIFIER_BUNDLE.verifyAction(proof, inputs), "Blackjack: invalid action proof");

        session.proofSequence += 1;
        session.playerStateCommitment = newPlayerStateCommitment;
        session.dealerStateCommitment = dealerStateCommitment;
        session.playerCiphertextRef = playerCiphertextRef;
        session.dealerCiphertextRef = dealerCiphertextRef;
        _applyPublicState(session, publicState);
        session.pendingAction = 0;
        session.pendingAdditionalBurn = 0;

        emit ActionResolved(sessionId, uint8(inputs.pendingAction), publicState.phase);
    }

    function submitShowdownProof(
        uint256 sessionId,
        bytes32 playerStateCommitment,
        bytes32 dealerStateCommitment,
        PublicSessionState calldata publicState,
        bytes calldata proof
    ) external {
        _requireSettlableModule();
        _requireCoordinator();

        Session storage session = sessions[sessionId];
        require(session.phase == SessionPhase.AwaitingCoordinatorAction, "Blackjack: no showdown");
        require(session.pendingAction == 0 || session.pendingAction == ACTION_STAND, "Blackjack: showdown blocked");

        IBlackjackVerifierBundle.ShowdownPublicInputs memory inputs =
            _buildShowdownInputs(sessionId, session, playerStateCommitment, dealerStateCommitment, publicState);
        require(VERIFIER_BUNDLE.verifyShowdown(proof, inputs), "Blackjack: invalid showdown proof");

        session.proofSequence += 1;
        session.playerStateCommitment = playerStateCommitment;
        session.dealerStateCommitment = dealerStateCommitment;
        _applyPublicState(session, publicState);
        session.pendingAction = 0;
        session.pendingAdditionalBurn = 0;

        emit ShowdownResolved(sessionId, publicState.payout);
    }

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
        viewState.pendingAction = session.pendingAction;
        viewState.decisionType = session.decisionType;
        viewState.dealerRevealMask = session.dealerRevealMask;
        viewState.handCount = session.handCount;
        viewState.activeHandIndex = session.activeHandIndex;
        viewState.peekAvailable = session.peekAvailable;
        viewState.peekResolved = session.peekResolved;
        viewState.dealerHasBlackjack = session.dealerHasBlackjack;
        viewState.insuranceAvailable = session.insuranceAvailable;
        viewState.insuranceStatus = session.insuranceStatus;
        viewState.surrenderAvailable = session.surrenderAvailable;
        viewState.surrenderStatus = session.surrenderStatus;
        viewState.dealerUpValue = session.dealerUpValue;
        viewState.dealerFinalValue = session.dealerFinalValue;
        viewState.payout = session.payout;
        viewState.insuranceStake = session.insuranceStake;
        viewState.insurancePayout = session.insurancePayout;
        for (uint256 i = 0; i < 4; i++) {
            viewState.hands[i] = session.hands[i];
        }
        viewState.playerCards = _copyCards(session.playerCards);
        viewState.dealerCards = _copyCards(session.dealerCards);
    }

    function getSettlementOutcome(uint256 sessionId)
        external
        view
        returns (address player, uint256 totalBurned, uint256 payout, bool completed)
    {
        Session storage session = sessions[sessionId];
        return (session.player, session.totalBurned, session.payout, session.phase == SessionPhase.Completed);
    }

    function _advanceDecisionWindow(Session storage session, bool fromTimeout) internal {
        if (session.phase == SessionPhase.AwaitingPrePlayDecision) {
            if (session.decisionType == DECISION_INSURANCE) {
                if (session.insuranceStatus == INSURANCE_AVAILABLE) {
                    session.insuranceStatus = INSURANCE_DECLINED;
                }
                session.insuranceAvailable = 0;
                session.phase = SessionPhase.AwaitingPeekResolution;
                session.deadlineAt = 0;
                return;
            }
            if (session.decisionType == DECISION_EARLY_SURRENDER) {
                if (session.surrenderStatus == SURRENDER_AVAILABLE) {
                    session.surrenderStatus = SURRENDER_DECLINED;
                }
                session.surrenderAvailable = 0;
                session.phase = SessionPhase.AwaitingPeekResolution;
                session.deadlineAt = 0;
                return;
            }
        }

        if (session.phase == SessionPhase.AwaitingPostPeekDecision) {
            if (session.surrenderStatus == SURRENDER_AVAILABLE) {
                session.surrenderStatus = fromTimeout ? SURRENDER_DECLINED : SURRENDER_DECLINED;
            }
            session.surrenderAvailable = 0;
            session.decisionType = DECISION_NONE;
            session.phase = SessionPhase.AwaitingPlayerAction;
            session.deadlineAt = block.timestamp + session.actionWindow;
            return;
        }

        revert("Blackjack: no decision");
    }

    function _applyPublicState(Session storage session, PublicSessionState calldata publicState) internal {
        session.phase = SessionPhase(publicState.phase);
        session.decisionType = publicState.decisionType;
        session.dealerRevealMask = publicState.dealerRevealMask;
        session.handCount = publicState.handCount;
        session.activeHandIndex = publicState.activeHandIndex;
        session.peekAvailable = publicState.peekAvailable;
        session.peekResolved = publicState.peekResolved;
        session.dealerHasBlackjack = publicState.dealerHasBlackjack;
        session.insuranceAvailable = publicState.insuranceAvailable;
        session.insuranceStatus = publicState.insuranceStatus;
        session.surrenderAvailable = publicState.surrenderAvailable;
        session.surrenderStatus = publicState.surrenderStatus;
        session.dealerUpValue = publicState.dealerUpValue;
        session.dealerFinalValue = publicState.dealerFinalValue;
        session.payout = publicState.payout;
        session.insuranceStake = publicState.insuranceStake;
        session.insurancePayout = publicState.insurancePayout;

        for (uint256 i = 0; i < 4; i++) {
            session.hands[i] = publicState.hands[i];
        }
        _replaceCards(session.playerCards, publicState.playerCards);
        _replaceCards(session.dealerCards, publicState.dealerCards);

        if (session.phase == SessionPhase.AwaitingPrePlayDecision
            || session.phase == SessionPhase.AwaitingPostPeekDecision
            || session.phase == SessionPhase.AwaitingPlayerAction) {
            session.deadlineAt = block.timestamp + session.actionWindow;
        } else {
            session.deadlineAt = 0;
        }
    }

    function _buildInitialDealInputs(
        uint256 sessionId,
        Session storage session,
        bytes32 deckCommitment,
        bytes32 handNonce,
        bytes32 playerStateCommitment,
        bytes32 dealerStateCommitment,
        bytes32 playerCiphertextRef,
        bytes32 dealerCiphertextRef,
        PublicSessionState calldata publicState
    ) internal view returns (IBlackjackVerifierBundle.InitialDealPublicInputs memory inputs) {
        inputs.sessionId = sessionId;
        inputs.handNonce = uint256(handNonce);
        inputs.deckCommitment = uint256(deckCommitment);
        inputs.playerStateCommitment = uint256(playerStateCommitment);
        inputs.dealerStateCommitment = uint256(dealerStateCommitment);
        inputs.playerKeyCommitment = uint256(session.playerKeyCommitment);
        inputs.playerCiphertextRef = uint256(playerCiphertextRef);
        inputs.dealerCiphertextRef = uint256(dealerCiphertextRef);
        _fillSharedState(inputs, publicState);
    }

    function _buildPeekInputs(
        uint256 sessionId,
        Session storage session,
        bytes32 playerStateCommitment,
        bytes32 dealerStateCommitment,
        bytes32 playerCiphertextRef,
        bytes32 dealerCiphertextRef,
        PublicSessionState calldata publicState
    ) internal view returns (IBlackjackVerifierBundle.PeekPublicInputs memory inputs) {
        inputs.sessionId = sessionId;
        inputs.proofSequence = session.proofSequence + 1;
        inputs.deckCommitment = uint256(session.deckCommitment);
        inputs.playerStateCommitment = uint256(playerStateCommitment);
        inputs.dealerStateCommitment = uint256(dealerStateCommitment);
        inputs.playerKeyCommitment = uint256(session.playerKeyCommitment);
        inputs.playerCiphertextRef = uint256(playerCiphertextRef);
        inputs.dealerCiphertextRef = uint256(dealerCiphertextRef);
        _fillSharedState(inputs, publicState);
    }

    function _buildActionInputs(
        uint256 sessionId,
        Session storage session,
        bytes32 newPlayerStateCommitment,
        bytes32 dealerStateCommitment,
        bytes32 playerCiphertextRef,
        bytes32 dealerCiphertextRef,
        PublicSessionState calldata publicState
    ) internal view returns (IBlackjackVerifierBundle.ActionPublicInputs memory inputs) {
        inputs.sessionId = sessionId;
        inputs.proofSequence = session.proofSequence + 1;
        inputs.pendingAction = session.pendingAction;
        inputs.deckCommitment = uint256(session.deckCommitment);
        inputs.oldPlayerStateCommitment = uint256(session.playerStateCommitment);
        inputs.newPlayerStateCommitment = uint256(newPlayerStateCommitment);
        inputs.dealerStateCommitment = uint256(dealerStateCommitment);
        inputs.playerKeyCommitment = uint256(session.playerKeyCommitment);
        inputs.playerCiphertextRef = uint256(playerCiphertextRef);
        inputs.dealerCiphertextRef = uint256(dealerCiphertextRef);
        _fillSharedState(inputs, publicState);
    }

    function _buildShowdownInputs(
        uint256 sessionId,
        Session storage session,
        bytes32 playerStateCommitment,
        bytes32 dealerStateCommitment,
        PublicSessionState calldata publicState
    ) internal view returns (IBlackjackVerifierBundle.ShowdownPublicInputs memory inputs) {
        inputs.sessionId = sessionId;
        inputs.proofSequence = session.proofSequence + 1;
        inputs.deckCommitment = uint256(session.deckCommitment);
        inputs.playerStateCommitment = uint256(playerStateCommitment);
        inputs.dealerStateCommitment = uint256(dealerStateCommitment);
        inputs.playerKeyCommitment = uint256(session.playerKeyCommitment);
        _fillSharedState(inputs, publicState);
    }

    function _fillSharedState(
        IBlackjackVerifierBundle.InitialDealPublicInputs memory inputs,
        PublicSessionState calldata publicState
    ) internal pure {
        inputs.phase = publicState.phase;
        inputs.decisionType = publicState.decisionType;
        inputs.dealerUpValue = publicState.dealerUpValue;
        inputs.dealerFinalValue = publicState.dealerFinalValue;
        inputs.payout = publicState.payout;
        inputs.insuranceStake = publicState.insuranceStake;
        inputs.insurancePayout = publicState.insurancePayout;
        inputs.dealerRevealMask = publicState.dealerRevealMask;
        inputs.handCount = publicState.handCount;
        inputs.activeHandIndex = publicState.activeHandIndex;
        inputs.peekAvailable = publicState.peekAvailable;
        inputs.peekResolved = publicState.peekResolved;
        inputs.dealerHasBlackjack = publicState.dealerHasBlackjack;
        inputs.insuranceAvailable = publicState.insuranceAvailable;
        inputs.insuranceStatus = publicState.insuranceStatus;
        inputs.surrenderAvailable = publicState.surrenderAvailable;
        inputs.surrenderStatus = publicState.surrenderStatus;
        _fillHandsAndCards(
            inputs.handWagers,
            inputs.handValues,
            inputs.handStatuses,
            inputs.allowedActionMasks,
            inputs.handCardCounts,
            inputs.handCardStartIndices,
            inputs.handPayoutKinds,
            inputs.playerCards,
            inputs.dealerCards,
            publicState
        );
    }

    function _fillSharedState(
        IBlackjackVerifierBundle.PeekPublicInputs memory inputs,
        PublicSessionState calldata publicState
    ) internal pure {
        inputs.phase = publicState.phase;
        inputs.decisionType = publicState.decisionType;
        inputs.dealerUpValue = publicState.dealerUpValue;
        inputs.dealerFinalValue = publicState.dealerFinalValue;
        inputs.payout = publicState.payout;
        inputs.insuranceStake = publicState.insuranceStake;
        inputs.insurancePayout = publicState.insurancePayout;
        inputs.dealerRevealMask = publicState.dealerRevealMask;
        inputs.handCount = publicState.handCount;
        inputs.activeHandIndex = publicState.activeHandIndex;
        inputs.peekAvailable = publicState.peekAvailable;
        inputs.peekResolved = publicState.peekResolved;
        inputs.dealerHasBlackjack = publicState.dealerHasBlackjack;
        inputs.insuranceAvailable = publicState.insuranceAvailable;
        inputs.insuranceStatus = publicState.insuranceStatus;
        inputs.surrenderAvailable = publicState.surrenderAvailable;
        inputs.surrenderStatus = publicState.surrenderStatus;
        _fillHandsAndCards(
            inputs.handWagers,
            inputs.handValues,
            inputs.handStatuses,
            inputs.allowedActionMasks,
            inputs.handCardCounts,
            inputs.handCardStartIndices,
            inputs.handPayoutKinds,
            inputs.playerCards,
            inputs.dealerCards,
            publicState
        );
    }

    function _fillSharedState(
        IBlackjackVerifierBundle.ActionPublicInputs memory inputs,
        PublicSessionState calldata publicState
    ) internal pure {
        inputs.phase = publicState.phase;
        inputs.decisionType = publicState.decisionType;
        inputs.dealerUpValue = publicState.dealerUpValue;
        inputs.dealerFinalValue = publicState.dealerFinalValue;
        inputs.payout = publicState.payout;
        inputs.insuranceStake = publicState.insuranceStake;
        inputs.insurancePayout = publicState.insurancePayout;
        inputs.dealerRevealMask = publicState.dealerRevealMask;
        inputs.handCount = publicState.handCount;
        inputs.activeHandIndex = publicState.activeHandIndex;
        inputs.peekAvailable = publicState.peekAvailable;
        inputs.peekResolved = publicState.peekResolved;
        inputs.dealerHasBlackjack = publicState.dealerHasBlackjack;
        inputs.insuranceAvailable = publicState.insuranceAvailable;
        inputs.insuranceStatus = publicState.insuranceStatus;
        inputs.surrenderAvailable = publicState.surrenderAvailable;
        inputs.surrenderStatus = publicState.surrenderStatus;
        _fillHandsAndCards(
            inputs.handWagers,
            inputs.handValues,
            inputs.handStatuses,
            inputs.allowedActionMasks,
            inputs.handCardCounts,
            inputs.handCardStartIndices,
            inputs.handPayoutKinds,
            inputs.playerCards,
            inputs.dealerCards,
            publicState
        );
    }

    function _fillSharedState(
        IBlackjackVerifierBundle.ShowdownPublicInputs memory inputs,
        PublicSessionState calldata publicState
    ) internal pure {
        inputs.phase = publicState.phase;
        inputs.decisionType = publicState.decisionType;
        inputs.dealerUpValue = publicState.dealerUpValue;
        inputs.dealerFinalValue = publicState.dealerFinalValue;
        inputs.payout = publicState.payout;
        inputs.insuranceStake = publicState.insuranceStake;
        inputs.insurancePayout = publicState.insurancePayout;
        inputs.dealerRevealMask = publicState.dealerRevealMask;
        inputs.handCount = publicState.handCount;
        inputs.activeHandIndex = publicState.activeHandIndex;
        inputs.peekAvailable = publicState.peekAvailable;
        inputs.peekResolved = publicState.peekResolved;
        inputs.dealerHasBlackjack = publicState.dealerHasBlackjack;
        inputs.insuranceAvailable = publicState.insuranceAvailable;
        inputs.insuranceStatus = publicState.insuranceStatus;
        inputs.surrenderAvailable = publicState.surrenderAvailable;
        inputs.surrenderStatus = publicState.surrenderStatus;
        _fillHandsAndCards(
            inputs.handWagers,
            inputs.handValues,
            inputs.handStatuses,
            inputs.allowedActionMasks,
            inputs.handCardCounts,
            inputs.handCardStartIndices,
            inputs.handPayoutKinds,
            inputs.playerCards,
            inputs.dealerCards,
            publicState
        );
    }

    function _fillHandsAndCards(
        uint256[4] memory handWagers,
        uint256[4] memory handValues,
        uint256[4] memory handStatuses,
        uint256[4] memory allowedActionMasks,
        uint256[4] memory handCardCounts,
        uint256[4] memory handCardStartIndices,
        uint256[4] memory handPayoutKinds,
        uint256[MAX_PLAYER_CARDS] memory playerCards,
        uint256[MAX_DEALER_CARDS] memory dealerCards,
        PublicSessionState calldata publicState
    ) internal pure {
        for (uint256 i = 0; i < 4; i++) {
            handWagers[i] = publicState.hands[i].wager;
            handValues[i] = publicState.hands[i].value;
            handStatuses[i] = publicState.hands[i].status;
            allowedActionMasks[i] = publicState.hands[i].allowedActionMask;
            handCardCounts[i] = publicState.hands[i].cardCount;
            handCardStartIndices[i] = publicState.hands[i].cardStartIndex;
            handPayoutKinds[i] = publicState.hands[i].payoutKind;
        }
        for (uint256 i = 0; i < MAX_PLAYER_CARDS; i++) {
            playerCards[i] = i < publicState.playerCards.length ? publicState.playerCards[i] : CARD_EMPTY;
        }
        for (uint256 i = 0; i < MAX_DEALER_CARDS; i++) {
            dealerCards[i] = i < publicState.dealerCards.length ? publicState.dealerCards[i] : CARD_EMPTY;
        }
    }

    function _copyCards(uint8[] storage cards) internal view returns (uint8[] memory out) {
        out = new uint8[](cards.length);
        for (uint256 i = 0; i < cards.length; i++) {
            out[i] = cards[i];
        }
    }

    function _replaceCards(uint8[] storage target, uint8[] calldata source) internal {
        while (target.length > 0) {
            target.pop();
        }
        for (uint256 i = 0; i < source.length; i++) {
            target.push(source[i]);
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
