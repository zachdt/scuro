// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {GameCatalog} from "../GameCatalog.sol";
import {ISoloLifecycleEngine} from "../interfaces/ISoloLifecycleEngine.sol";
import {BaccaratRules} from "../libraries/BaccaratRules.sol";
import {BaccaratTypes} from "../libraries/BaccaratTypes.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

/// @title Solo super baccarat engine
/// @notice Resolves EV-neutral baccarat picks from VRF-backed fresh shoes.
contract SuperBaccaratEngine is ISoloLifecycleEngine {
    bytes32 public constant ENGINE_TYPE = keccak256("BACCARAT_SUPER_SOLO");

    uint256 public constant PUSH_PAYOUT_WAD = 1e18;
    uint256 public constant PLAYER_PAYOUT_WAD = 2_027_677_102_818_402_306;
    uint256 public constant BANKER_PAYOUT_WAD = 1_973_068_288_918_281_910;
    uint256 public constant TIE_PAYOUT_WAD = 10_509_062_340_173_595_362;

    struct PlayRequest {
        address player;
        uint256 wager;
        BaccaratTypes.BaccaratSide side;
        bytes32 playRef;
        uint256 payout;
        bool fulfilled;
        BaccaratTypes.BaccaratRoundView round;
    }

    GameCatalog internal immutable CATALOG;
    address public immutable vrfCoordinator;

    uint256 public totalGamesPlayed;
    uint256 public totalWagers;
    uint256 public totalPayouts;

    mapping(uint256 => PlayRequest) internal playRequests;

    event PlayRequested(
        uint256 indexed requestId,
        address indexed player,
        bytes32 indexed playRef,
        uint256 wager,
        BaccaratTypes.BaccaratSide side
    );
    event PlayResolved(
        uint256 indexed requestId,
        address indexed player,
        BaccaratTypes.BaccaratOutcome outcome,
        BaccaratTypes.BaccaratSide side,
        uint256 payout
    );

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

    function requestPlay(address player, uint256 wager, uint8 side, bytes32 playRef) external returns (uint256 requestId) {
        require(CATALOG.isAuthorizedControllerForEngine(msg.sender, address(this)), "SuperBaccarat: not controller");
        require(wager > 0, "SuperBaccarat: invalid wager");
        require(side <= uint8(BaccaratTypes.BaccaratSide.Tie), "SuperBaccarat: invalid side");

        requestId = _getNextRequestId();
        PlayRequest storage playRequest = playRequests[requestId];
        playRequest.player = player;
        playRequest.wager = wager;
        playRequest.side = BaccaratTypes.BaccaratSide(side);
        playRequest.playRef = playRef;

        totalGamesPlayed += 1;
        totalWagers += wager;

        emit PlayRequested(requestId, player, playRef, wager, playRequest.side);

        uint256 actualId = _requestRandomness();
        require(actualId == requestId, "SuperBaccarat: request mismatch");
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        require(CATALOG.isSettlableEngine(address(this)), "SuperBaccarat: module inactive");
        require(msg.sender == vrfCoordinator, "SuperBaccarat: bad coordinator");

        PlayRequest storage playRequest = playRequests[requestId];
        require(playRequest.player != address(0), "SuperBaccarat: unknown request");
        require(!playRequest.fulfilled, "SuperBaccarat: fulfilled");

        BaccaratTypes.BaccaratRoundView memory round = BaccaratRules.resolve(randomWords[0]);
        uint256 payout = _computePayout(playRequest.wager, playRequest.side, round.outcome);

        playRequest.round = round;
        playRequest.payout = payout;
        playRequest.fulfilled = true;
        totalPayouts += payout;

        emit PlayResolved(requestId, playRequest.player, round.outcome, playRequest.side, payout);
    }

    function getRound(uint256 requestId)
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
            bool fulfilled
        )
    {
        PlayRequest storage playRequest = playRequests[requestId];
        BaccaratTypes.BaccaratRoundView storage round = playRequest.round;
        return (
            round.playerCards,
            round.bankerCards,
            round.playerCardCount,
            round.bankerCardCount,
            round.playerTotal,
            round.bankerTotal,
            round.natural,
            round.outcome,
            round.randomWord,
            playRequest.fulfilled
        );
    }

    function getSettlementOutcome(uint256 requestId)
        external
        view
        returns (address player, uint256 totalBurned, uint256 payout, bool completed)
    {
        PlayRequest storage playRequest = playRequests[requestId];
        return (playRequest.player, playRequest.wager, playRequest.payout, playRequest.fulfilled);
    }

    function payoutMultiplierWad(BaccaratTypes.BaccaratSide side) public pure returns (uint256) {
        if (side == BaccaratTypes.BaccaratSide.Player) {
            return PLAYER_PAYOUT_WAD;
        }
        if (side == BaccaratTypes.BaccaratSide.Banker) {
            return BANKER_PAYOUT_WAD;
        }
        return TIE_PAYOUT_WAD;
    }

    function _computePayout(uint256 wager, BaccaratTypes.BaccaratSide side, BaccaratTypes.BaccaratOutcome outcome)
        internal
        pure
        returns (uint256)
    {
        if (outcome == BaccaratTypes.BaccaratOutcome.Tie) {
            if (side == BaccaratTypes.BaccaratSide.Tie) {
                return Math.mulDiv(wager, TIE_PAYOUT_WAD, 1e18);
            }
            return Math.mulDiv(wager, PUSH_PAYOUT_WAD, 1e18);
        }

        if (side == BaccaratTypes.BaccaratSide.Tie) {
            return 0;
        }

        if (
            (side == BaccaratTypes.BaccaratSide.Player && outcome == BaccaratTypes.BaccaratOutcome.PlayerWin)
                || (side == BaccaratTypes.BaccaratSide.Banker && outcome == BaccaratTypes.BaccaratOutcome.BankerWin)
        ) {
            return Math.mulDiv(wager, payoutMultiplierWad(side), 1e18);
        }

        return 0;
    }

    function _getNextRequestId() internal view returns (uint256) {
        (bool success, bytes memory data) = vrfCoordinator.staticcall(abi.encodeWithSignature("requestCounter()"));
        require(success, "SuperBaccarat: counter failed");
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
        require(success, "SuperBaccarat: vrf failed");
        return abi.decode(data, (uint256));
    }
}
