// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "openzeppelin-contracts/contracts/utils/Nonces.sol";
import {ScuroToken} from "./ScuroToken.sol";

/// @title Scuro staking token
/// @notice Liquid staking wrapper over SCU that also serves as the governance voting token.
contract ScuroStakingToken is ERC20, ERC20Permit, ERC20Votes {
    ScuroToken internal immutable ASSET;

    /// @notice Initializes the staking wrapper for a specific SCU token.
    constructor(address token) ERC20("Staked Scuro", "sSCU") ERC20Permit("Staked Scuro") {
        ASSET = ScuroToken(token);
    }

    /// @notice Returns the underlying SCU token deposited into the wrapper.
    function asset() public view returns (ScuroToken) {
        return ASSET;
    }

    /// @notice Stakes SCU 1:1 and mints the same amount of sSCU to the caller.
    function stake(uint256 amount) external {
        require(amount > 0, "Staking: zero amount");
        require(ASSET.transferFrom(msg.sender, address(this), amount), "Staking: transfer failed");
        _mint(msg.sender, amount);
    }

    /// @notice Burns sSCU 1:1 and withdraws the same amount of SCU to the caller.
    function unstake(uint256 amount) external {
        require(amount > 0, "Staking: zero amount");
        _burn(msg.sender, amount);
        require(ASSET.transfer(msg.sender, amount), "Staking: transfer failed");
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    /// @notice Returns the next permit nonce for an owner.
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
