// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeveloperExpressionRegistry} from "./DeveloperExpressionRegistry.sol";
import {DeveloperRewards} from "./DeveloperRewards.sol";
import {GameCatalog} from "./GameCatalog.sol";
import {ScuroToken} from "./ScuroToken.sol";

contract ProtocolSettlement {
    ScuroToken internal immutable TOKEN;
    DeveloperRewards internal immutable DEVELOPER_REWARDS;
    DeveloperExpressionRegistry internal immutable EXPRESSION_REGISTRY;
    GameCatalog internal immutable CATALOG;

    event PlayerWagerBurned(address indexed player, uint256 amount, address indexed caller);
    event PlayerRewardMinted(address indexed player, uint256 amount, address indexed caller);
    event DeveloperAccrualRecorded(
        address indexed engine,
        uint256 indexed expressionTokenId,
        address indexed developer,
        uint256 activityAmount,
        uint256 accrual
    );

    constructor(address tokenAddress, address catalogAddress, address expressionRegistryAddress, address developerRewardsAddress) {
        TOKEN = ScuroToken(tokenAddress);
        CATALOG = GameCatalog(catalogAddress);
        EXPRESSION_REGISTRY = DeveloperExpressionRegistry(expressionRegistryAddress);
        DEVELOPER_REWARDS = DeveloperRewards(developerRewardsAddress);
    }

    function token() public view returns (ScuroToken) {
        return TOKEN;
    }

    function developerRewards() public view returns (DeveloperRewards) {
        return DEVELOPER_REWARDS;
    }

    function expressionRegistry() public view returns (DeveloperExpressionRegistry) {
        return EXPRESSION_REGISTRY;
    }

    function catalog() public view returns (GameCatalog) {
        return CATALOG;
    }

    function burnPlayerWager(address player, uint256 amount) external {
        _requireAuthorizedController();
        TOKEN.burnFrom(player, amount);
        emit PlayerWagerBurned(player, amount, msg.sender);
    }

    function mintPlayerReward(address player, uint256 amount) external {
        _requireAuthorizedController();
        if (amount == 0) {
            return;
        }

        TOKEN.mint(player, amount);
        emit PlayerRewardMinted(player, amount, msg.sender);
    }

    function accrueDeveloperForExpression(uint256 expressionTokenId, uint256 activityAmount)
        external
        returns (uint256 accrual)
    {
        GameCatalog.Module memory moduleData = _requireAuthorizedController();
        if (activityAmount == 0) {
            return 0;
        }

        DeveloperExpressionRegistry.ExpressionMetadata memory expressionMetadata =
            EXPRESSION_REGISTRY.getExpressionMetadata(expressionTokenId);
        require(expressionMetadata.active, "Settlement: expression inactive");
        require(expressionMetadata.engineType == moduleData.engineType, "Settlement: expression mismatch");

        uint16 developerRewardBps = moduleData.developerRewardBps;
        if (developerRewardBps == 0) {
            return 0;
        }

        address developer = EXPRESSION_REGISTRY.ownerOf(expressionTokenId);
        accrual = (activityAmount * developerRewardBps) / 10_000;
        DEVELOPER_REWARDS.accrue(developer, accrual);
        emit DeveloperAccrualRecorded(moduleData.engine, expressionTokenId, developer, activityAmount, accrual);
    }

    function _requireAuthorizedController() internal view returns (GameCatalog.Module memory moduleData) {
        require(CATALOG.isSettlableController(msg.sender), "Settlement: unauthorized controller");
        moduleData = CATALOG.getModuleByController(msg.sender);
    }
}
