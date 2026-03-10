// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract VRFCoordinatorMock {
    uint256 public requestCounter;

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32,
        uint32 numWords
    ) external returns (uint256 requestId) {
        requestId = ++requestCounter;
        uint256[] memory randomWords = new uint256[](numWords);
        for (uint32 i = 0; i < numWords; i++) {
            randomWords[i] = uint256(
                keccak256(abi.encodePacked(block.prevrandao, block.timestamp, msg.sender, requestId, i))
            );
        }

        (bool success,) = msg.sender.call(
            abi.encodeWithSignature("rawFulfillRandomWords(uint256,uint256[])", requestId, randomWords)
        );
        require(success, "VRFMock: callback failed");
    }
}
