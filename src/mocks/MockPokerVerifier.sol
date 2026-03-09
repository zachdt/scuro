// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPokerVerifier} from "../interfaces/IPokerVerifier.sol";

contract MockPokerVerifier is IPokerVerifier {
    bool public shouldVerify = true;

    function setShouldVerify(bool newValue) external {
        shouldVerify = newValue;
    }

    function verify(bytes calldata, bytes32) external view returns (bool) {
        return shouldVerify;
    }
}
