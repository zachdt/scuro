// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "./ScuroToken.sol";
import "./CreatorRewards.sol";
import "./GameEngineRegistry.sol";

contract ProtocolSettlement is AccessControl {
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    ScuroToken public immutable token;
    CreatorRewards public immutable creatorRewards;
    GameEngineRegistry public immutable registry;

    event PlayerWagerBurned(address indexed player, uint256 amount, address indexed caller);
    event PlayerRewardMinted(address indexed player, uint256 amount, address indexed caller);
    event CreatorAccrualRecorded(address indexed engine, address indexed creator, uint256 activityAmount, uint256 accrual);

    constructor(address admin, address tokenAddress, address registryAddress, address creatorRewardsAddress) {
        token = ScuroToken(tokenAddress);
        registry = GameEngineRegistry(registryAddress);
        creatorRewards = CreatorRewards(creatorRewardsAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONTROLLER_ROLE, admin);
    }

    function setControllerAuthorization(address controller, bool authorized) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (authorized) {
            _grantRole(CONTROLLER_ROLE, controller);
        } else {
            _revokeRole(CONTROLLER_ROLE, controller);
        }
    }

    function burnPlayerWager(address player, uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        token.burnFrom(player, amount);
        emit PlayerWagerBurned(player, amount, msg.sender);
    }

    function mintPlayerReward(address player, uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        if (amount == 0) {
            return;
        }

        token.mint(player, amount);
        emit PlayerRewardMinted(player, amount, msg.sender);
    }

    function accrueCreatorForEngine(address engine, uint256 activityAmount)
        external
        onlyRole(CONTROLLER_ROLE)
        returns (uint256 accrual)
    {
        (address creator, uint16 creatorRateBps) = registry.getCreatorConfig(engine);
        if (creator == address(0) || creatorRateBps == 0 || activityAmount == 0) {
            return 0;
        }

        accrual = (activityAmount * creatorRateBps) / 10_000;
        creatorRewards.accrue(creator, accrual);
        emit CreatorAccrualRecorded(engine, creator, activityAmount, accrual);
    }
}
