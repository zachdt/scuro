// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaccaratTypes} from "./BaccaratTypes.sol";

/// @title Baccarat rules library
/// @notice Resolves fresh eight-deck punto banco rounds from a single VRF word.
library BaccaratRules {
    uint8 internal constant CARD_VALUE_COUNT = 10;
    uint16 internal constant ZERO_VALUE_CARD_COUNT = 128;
    uint16 internal constant PIP_CARD_COUNT = 32;
    uint16 internal constant TOTAL_CARDS = 416;
    uint8 internal constant PLAYER_DRAW_SENTINEL = type(uint8).max;

    function resolve(uint256 randomWord) internal pure returns (BaccaratTypes.BaccaratRoundView memory round) {
        uint16[CARD_VALUE_COUNT] memory counts = _freshShoe();
        uint16 remaining = TOTAL_CARDS;
        uint256 entropy = randomWord;

        round.randomWord = randomWord;

        (round.playerCards[0], entropy, remaining) = _drawCard(counts, remaining, entropy);
        (round.bankerCards[0], entropy, remaining) = _drawCard(counts, remaining, entropy);
        (round.playerCards[1], entropy, remaining) = _drawCard(counts, remaining, entropy);
        (round.bankerCards[1], entropy, remaining) = _drawCard(counts, remaining, entropy);

        round.playerCardCount = 2;
        round.bankerCardCount = 2;
        round.playerTotal = (round.playerCards[0] + round.playerCards[1]) % 10;
        round.bankerTotal = (round.bankerCards[0] + round.bankerCards[1]) % 10;
        round.natural = round.playerTotal >= 8 || round.bankerTotal >= 8;

        if (!round.natural) {
            bool playerDrew = playerDraws(round.playerTotal);
            uint8 playerThirdValue = PLAYER_DRAW_SENTINEL;
            if (playerDrew) {
                (round.playerCards[2], entropy, remaining) = _drawCard(counts, remaining, entropy);
                round.playerCardCount = 3;
                playerThirdValue = round.playerCards[2];
                round.playerTotal = (round.playerTotal + playerThirdValue) % 10;
            }

            if (bankerDraws(round.bankerTotal, playerDrew, playerThirdValue)) {
                (round.bankerCards[2], entropy, remaining) = _drawCard(counts, remaining, entropy);
                round.bankerCardCount = 3;
                round.bankerTotal = (round.bankerTotal + round.bankerCards[2]) % 10;
            }
        }

        round.outcome = compareTotals(round.playerTotal, round.bankerTotal);
    }

    function playerDraws(uint8 playerTotal) internal pure returns (bool) {
        return playerTotal <= 5;
    }

    function bankerDraws(uint8 bankerTotal, bool playerDrew, uint8 playerThirdValue) internal pure returns (bool) {
        if (!playerDrew) {
            return bankerTotal <= 5;
        }

        if (bankerTotal <= 2) {
            return true;
        }
        if (bankerTotal == 3) {
            return playerThirdValue != 8;
        }
        if (bankerTotal == 4) {
            return playerThirdValue >= 2 && playerThirdValue <= 7;
        }
        if (bankerTotal == 5) {
            return playerThirdValue >= 4 && playerThirdValue <= 7;
        }
        if (bankerTotal == 6) {
            return playerThirdValue == 6 || playerThirdValue == 7;
        }

        return false;
    }

    function compareTotals(uint8 playerTotal, uint8 bankerTotal)
        internal
        pure
        returns (BaccaratTypes.BaccaratOutcome)
    {
        if (playerTotal > bankerTotal) {
            return BaccaratTypes.BaccaratOutcome.PlayerWin;
        }
        if (bankerTotal > playerTotal) {
            return BaccaratTypes.BaccaratOutcome.BankerWin;
        }
        return BaccaratTypes.BaccaratOutcome.Tie;
    }

    function _freshShoe() private pure returns (uint16[CARD_VALUE_COUNT] memory counts) {
        counts[0] = ZERO_VALUE_CARD_COUNT;
        for (uint256 i = 1; i < CARD_VALUE_COUNT; i++) {
            counts[i] = PIP_CARD_COUNT;
        }
    }

    function _drawCard(uint16[CARD_VALUE_COUNT] memory counts, uint16 remaining, uint256 entropy)
        private
        pure
        returns (uint8 value, uint256 nextEntropy, uint16 nextRemaining)
    {
        uint256 ticket = entropy % remaining;
        uint256 cumulative = 0;
        for (uint8 i = 0; i < CARD_VALUE_COUNT; i++) {
            cumulative += counts[i];
            if (ticket < cumulative) {
                value = i;
                counts[i] -= 1;
                nextRemaining = remaining - 1;
                nextEntropy = uint256(keccak256(abi.encodePacked(entropy, remaining, i, ticket)));
                return (value, nextEntropy, nextRemaining);
            }
        }

        revert("BaccaratRules: draw failed");
    }
}
