// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ScuroToken} from "./ScuroToken.sol";

/// @title Scuro developer rewards
/// @notice Tracks per-epoch developer accrual and mints SCU when closed epochs are claimed.
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

    /// @notice Emitted when settlement books developer activity into the current epoch.
    event DeveloperAccrued(uint256 indexed epoch, address indexed developer, uint256 amount);
    /// @notice Emitted when the current epoch closes and a new epoch begins.
    event EpochClosed(uint256 indexed epoch, uint256 nextEpoch, uint256 nextEpochStart);
    /// @notice Emitted when a developer claims a closed epoch accrual.
    event DeveloperClaimed(uint256 indexed epoch, address indexed developer, uint256 amount);

    /// @notice Initializes rewards accounting and grants operational roles to the admin.
    constructor(address admin, address tokenAddress, uint256 epochDurationSeconds) {
        require(epochDurationSeconds > 0, "DeveloperRewards: invalid duration");
        TOKEN = ScuroToken(tokenAddress);
        epochDuration = epochDurationSeconds;
        epochStart = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SETTLEMENT_ROLE, admin);
        _grantRole(EPOCH_MANAGER_ROLE, admin);
    }

    /// @notice Returns the SCU token minted for claims.
    function token() public view returns (ScuroToken) {
        return TOKEN;
    }

    /// @notice Updates the minimum wall-clock duration required before an epoch can close.
    function setEpochDuration(uint256 newDuration) external onlyRole(EPOCH_MANAGER_ROLE) {
        require(newDuration > 0, "DeveloperRewards: invalid duration");
        epochDuration = newDuration;
    }

    /// @notice Accrues rewards for a developer in the current epoch.
    function accrue(address developer, uint256 amount) external onlyRole(SETTLEMENT_ROLE) {
        if (developer == address(0) || amount == 0) {
            return;
        }

        epochAccrual[currentEpoch][developer] += amount;
        emit DeveloperAccrued(currentEpoch, developer, amount);
    }

    /// @notice Closes the current epoch and advances accounting to the next epoch.
    function closeCurrentEpoch() external onlyRole(EPOCH_MANAGER_ROLE) returns (uint256 closedEpoch) {
        require(block.timestamp >= epochStart + epochDuration, "DeveloperRewards: epoch active");
        closedEpoch = currentEpoch;
        epochClosed[closedEpoch] = true;
        currentEpoch = closedEpoch + 1;
        epochStart = block.timestamp;
        emit EpochClosed(closedEpoch, currentEpoch, epochStart);
    }

    /// @notice Claims one or more closed epochs for the caller and returns the total minted amount.
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
