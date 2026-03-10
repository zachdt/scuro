// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ScuroToken} from "./ScuroToken.sol";

contract DeveloperRewards is AccessControl {
    bytes32 public constant SETTLEMENT_ROLE = keccak256("SETTLEMENT_ROLE");
    bytes32 public constant EPOCH_MANAGER_ROLE = keccak256("EPOCH_MANAGER_ROLE");

    ScuroToken internal immutable TOKEN;
    uint256 public currentEpoch = 1;
    uint256 public epochDuration;
    uint256 public epochStart;

    mapping(uint256 => bool) public epochClosed;
    mapping(uint256 => mapping(address => uint256)) public epochAccrual;
    mapping(uint256 => mapping(address => bool)) public epochClaimed;

    event DeveloperAccrued(uint256 indexed epoch, address indexed developer, uint256 amount);
    event EpochClosed(uint256 indexed epoch, uint256 nextEpoch, uint256 nextEpochStart);
    event DeveloperClaimed(uint256 indexed epoch, address indexed developer, uint256 amount);

    constructor(address admin, address tokenAddress, uint256 epochDurationSeconds) {
        require(epochDurationSeconds > 0, "DeveloperRewards: invalid duration");
        TOKEN = ScuroToken(tokenAddress);
        epochDuration = epochDurationSeconds;
        epochStart = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SETTLEMENT_ROLE, admin);
        _grantRole(EPOCH_MANAGER_ROLE, admin);
    }

    function token() public view returns (ScuroToken) {
        return TOKEN;
    }

    function setEpochDuration(uint256 newDuration) external onlyRole(EPOCH_MANAGER_ROLE) {
        require(newDuration > 0, "DeveloperRewards: invalid duration");
        epochDuration = newDuration;
    }

    function accrue(address developer, uint256 amount) external onlyRole(SETTLEMENT_ROLE) {
        if (developer == address(0) || amount == 0) {
            return;
        }

        epochAccrual[currentEpoch][developer] += amount;
        emit DeveloperAccrued(currentEpoch, developer, amount);
    }

    function closeCurrentEpoch() external onlyRole(EPOCH_MANAGER_ROLE) returns (uint256 closedEpoch) {
        require(block.timestamp >= epochStart + epochDuration, "DeveloperRewards: epoch active");
        closedEpoch = currentEpoch;
        epochClosed[closedEpoch] = true;
        currentEpoch = closedEpoch + 1;
        epochStart = block.timestamp;
        emit EpochClosed(closedEpoch, currentEpoch, epochStart);
    }

    function claim(uint256[] calldata epochs) external returns (uint256 totalClaimed) {
        for (uint256 i = 0; i < epochs.length; i++) {
            uint256 epoch = epochs[i];
            require(epochClosed[epoch], "DeveloperRewards: epoch open");
            require(!epochClaimed[epoch][msg.sender], "DeveloperRewards: already claimed");
            uint256 amount = epochAccrual[epoch][msg.sender];
            if (amount == 0) {
                epochClaimed[epoch][msg.sender] = true;
                continue;
            }

            epochClaimed[epoch][msg.sender] = true;
            totalClaimed += amount;
            emit DeveloperClaimed(epoch, msg.sender, amount);
        }

        if (totalClaimed > 0) {
            TOKEN.mint(msg.sender, totalClaimed);
        }
    }
}
