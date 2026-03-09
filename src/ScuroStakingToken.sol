// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "./ScuroToken.sol";

contract ScuroStakingToken is ERC20, ERC20Permit, ERC20Votes {
    ScuroToken public immutable asset;

    constructor(address token) ERC20("Staked Scuro", "sSCU") ERC20Permit("Staked Scuro") {
        asset = ScuroToken(token);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Staking: zero amount");
        asset.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "Staking: zero amount");
        _burn(msg.sender, amount);
        asset.transfer(msg.sender, amount);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
