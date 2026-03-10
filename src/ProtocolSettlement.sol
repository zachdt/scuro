// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {DeveloperExpressionRegistry} from "./DeveloperExpressionRegistry.sol";
import {DeveloperRewards} from "./DeveloperRewards.sol";
import {GameEngineRegistry} from "./GameEngineRegistry.sol";
import {ScuroToken} from "./ScuroToken.sol";

contract ProtocolSettlement is AccessControl {
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    ScuroToken internal immutable TOKEN;
    DeveloperRewards internal immutable DEVELOPER_REWARDS;
    DeveloperExpressionRegistry internal immutable EXPRESSION_REGISTRY;
    GameEngineRegistry internal immutable REGISTRY;

    event PlayerWagerBurned(address indexed player, uint256 amount, address indexed caller);
    event PlayerRewardMinted(address indexed player, uint256 amount, address indexed caller);
    event DeveloperAccrualRecorded(
        address indexed engine,
        uint256 indexed expressionTokenId,
        address indexed developer,
        uint256 activityAmount,
        uint256 accrual
    );

    constructor(
        address admin,
        address tokenAddress,
        address registryAddress,
        address expressionRegistryAddress,
        address developerRewardsAddress
    ) {
        TOKEN = ScuroToken(tokenAddress);
        REGISTRY = GameEngineRegistry(registryAddress);
        EXPRESSION_REGISTRY = DeveloperExpressionRegistry(expressionRegistryAddress);
        DEVELOPER_REWARDS = DeveloperRewards(developerRewardsAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONTROLLER_ROLE, admin);
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

    function registry() public view returns (GameEngineRegistry) {
        return REGISTRY;
    }

    function setControllerAuthorization(address controller, bool authorized) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (authorized) {
            _grantRole(CONTROLLER_ROLE, controller);
        } else {
            _revokeRole(CONTROLLER_ROLE, controller);
        }
    }

    function burnPlayerWager(address player, uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        TOKEN.burnFrom(player, amount);
        emit PlayerWagerBurned(player, amount, msg.sender);
    }

    function mintPlayerReward(address player, uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        if (amount == 0) {
            return;
        }

        TOKEN.mint(player, amount);
        emit PlayerRewardMinted(player, amount, msg.sender);
    }

    function accrueDeveloperForExpression(address engine, uint256 expressionTokenId, uint256 activityAmount)
        external
        onlyRole(CONTROLLER_ROLE)
        returns (uint256 accrual)
    {
        if (activityAmount == 0) {
            return 0;
        }

        GameEngineRegistry.EngineMetadata memory engineMetadata = REGISTRY.getEngineMetadata(engine);
        require(engineMetadata.active, "Settlement: engine inactive");

        DeveloperExpressionRegistry.ExpressionMetadata memory expressionMetadata =
            EXPRESSION_REGISTRY.getExpressionMetadata(expressionTokenId);
        require(expressionMetadata.active, "Settlement: expression inactive");
        require(expressionMetadata.engineType == engineMetadata.engineType, "Settlement: expression mismatch");

        uint16 developerRewardBps = engineMetadata.developerRewardBps;
        if (developerRewardBps == 0) {
            return 0;
        }

        address developer = EXPRESSION_REGISTRY.ownerOf(expressionTokenId);
        accrual = (activityAmount * developerRewardBps) / 10_000;
        DEVELOPER_REWARDS.accrue(developer, accrual);
        emit DeveloperAccrualRecorded(engine, expressionTokenId, developer, activityAmount, accrual);
    }
}
