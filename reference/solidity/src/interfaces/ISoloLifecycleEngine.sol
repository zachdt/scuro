// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IScuroGameEngine} from "./IScuroGameEngine.sol";

interface ISoloLifecycleEngine is IScuroGameEngine {
    function getSettlementOutcome(uint256 sessionId)
        external
        view
        returns (address player, uint256 totalBurned, uint256 payout, bool completed);
}
