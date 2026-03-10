// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {GameCatalog} from "../GameCatalog.sol";
import {ProtocolSettlement} from "../ProtocolSettlement.sol";

abstract contract BaseSoloController {
    ProtocolSettlement internal immutable SETTLEMENT;
    GameCatalog internal immutable CATALOG;
    address internal immutable ENGINE_ADDRESS;

    mapping(uint256 => bool) internal SESSION_SETTLED;
    mapping(uint256 => uint256) internal SESSION_EXPRESSION_TOKEN_ID;

    constructor(address settlementAddress, address catalogAddress, address engineAddress_) {
        SETTLEMENT = ProtocolSettlement(settlementAddress);
        CATALOG = GameCatalog(catalogAddress);
        ENGINE_ADDRESS = engineAddress_;
    }

    function settlement() public view returns (ProtocolSettlement) {
        return SETTLEMENT;
    }

    function catalog() public view returns (GameCatalog) {
        return CATALOG;
    }

    function engineAddress() public view returns (address) {
        return ENGINE_ADDRESS;
    }

    function _requireLaunchable(string memory errorMessage) internal view {
        require(CATALOG.isLaunchableController(address(this)), errorMessage);
    }

    function _requireSettlable(string memory errorMessage) internal view {
        require(CATALOG.isSettlableController(address(this)), errorMessage);
    }

    function _burnPlayerWager(address player, uint256 amount) internal {
        if (amount > 0) {
            SETTLEMENT.burnPlayerWager(player, amount);
        }
    }

    function _recordExpressionTokenId(uint256 sessionId, uint256 expressionTokenId) internal {
        SESSION_EXPRESSION_TOKEN_ID[sessionId] = expressionTokenId;
    }

    function _expressionTokenId(uint256 sessionId) internal view returns (uint256) {
        return SESSION_EXPRESSION_TOKEN_ID[sessionId];
    }

    function _isSettled(uint256 sessionId) internal view returns (bool) {
        return SESSION_SETTLED[sessionId];
    }

    function _markSettled(uint256 sessionId, string memory errorMessage) internal {
        require(!SESSION_SETTLED[sessionId], errorMessage);
        SESSION_SETTLED[sessionId] = true;
    }

    function _mintAndAccrue(address player, uint256 payout, uint256 totalBurned, uint256 expressionTokenId) internal {
        if (payout > 0) {
            SETTLEMENT.mintPlayerReward(player, payout);
        }
        SETTLEMENT.accrueDeveloperForExpression(expressionTokenId, totalBurned);
    }
}
