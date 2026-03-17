// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaccaratRules} from "../../src/libraries/BaccaratRules.sol";
import {BaccaratTypes} from "../../src/libraries/BaccaratTypes.sol";

contract BaccaratRulesHarness {
    function resolve(uint256 randomWord)
        external
        pure
        returns (
            BaccaratTypes.BaccaratOutcome outcome,
            bool natural,
            uint8 playerCardCount,
            uint8 bankerCardCount,
            uint8 playerTotal,
            uint8 bankerTotal
        )
    {
        BaccaratTypes.BaccaratRoundView memory round = BaccaratRules.resolve(randomWord);
        return (round.outcome, round.natural, round.playerCardCount, round.bankerCardCount, round.playerTotal, round.bankerTotal);
    }

    function playerDraws(uint8 playerTotal) external pure returns (bool) {
        return BaccaratRules.playerDraws(playerTotal);
    }

    function bankerDraws(uint8 bankerTotal, bool playerDrew, uint8 playerThirdValue) external pure returns (bool) {
        return BaccaratRules.bankerDraws(bankerTotal, playerDrew, playerThirdValue);
    }

    function compareTotals(uint8 playerTotal, uint8 bankerTotal) external pure returns (BaccaratTypes.BaccaratOutcome) {
        return BaccaratRules.compareTotals(playerTotal, bankerTotal);
    }
}
