// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title Baccarat shared types
/// @notice Namespaces enums and round views shared across baccarat engines and controllers.
library BaccaratTypes {
    enum BaccaratSide {
        Player,
        Banker,
        Tie
    }

    enum BaccaratOutcome {
        PlayerWin,
        BankerWin,
        Tie
    }

    struct BaccaratRoundView {
        uint8[3] playerCards;
        uint8[3] bankerCards;
        uint8 playerCardCount;
        uint8 bankerCardCount;
        uint8 playerTotal;
        uint8 bankerTotal;
        bool natural;
        BaccaratOutcome outcome;
        uint256 randomWord;
    }
}
