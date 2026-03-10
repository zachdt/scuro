// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {CreatorRewards} from "./CreatorRewards.sol";
import {GameEngineRegistry} from "./GameEngineRegistry.sol";
import {ScuroToken} from "./ScuroToken.sol";

contract ProtocolSettlement is AccessControl {
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    ScuroToken internal immutable TOKEN;
    CreatorRewards internal immutable CREATOR_REWARDS;
    GameEngineRegistry internal immutable REGISTRY;

    event PlayerWagerBurned(address indexed player, uint256 amount, address indexed caller);
    event PlayerRewardMinted(address indexed player, uint256 amount, address indexed caller);
    event CreatorAccrualRecorded(address indexed engine, address indexed creator, uint256 activityAmount, uint256 accrual);

    constructor(address admin, address tokenAddress, address registryAddress, address creatorRewardsAddress) {
        TOKEN = ScuroToken(tokenAddress);
        REGISTRY = GameEngineRegistry(registryAddress);
        CREATOR_REWARDS = CreatorRewards(creatorRewardsAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONTROLLER_ROLE, admin);
    }

    function token() public view returns (ScuroToken) {
        return TOKEN;
    }

    function creatorRewards() public view returns (CreatorRewards) {
        return CREATOR_REWARDS;
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

    function accrueCreatorForEngine(address engine, uint256 activityAmount)
        external
        onlyRole(CONTROLLER_ROLE)
        returns (uint256 accrual)
    {
        (address creator, uint16 creatorRateBps) = REGISTRY.getCreatorConfig(engine);
        if (creator == address(0) || creatorRateBps == 0 || activityAmount == 0) {
            return 0;
        }

        accrual = (activityAmount * creatorRateBps) / 10_000;
        CREATOR_REWARDS.accrue(creator, accrual);
        emit CreatorAccrualRecorded(engine, creator, activityAmount, accrual);
    }
}
