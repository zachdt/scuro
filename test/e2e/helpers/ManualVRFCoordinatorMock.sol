// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ManualVRFCoordinatorMock {
    struct PendingRequest {
        address requester;
        uint32 numWords;
        bool fulfilled;
    }

    uint256 public requestCounter;
    mapping(uint256 => PendingRequest) public pendingRequests;

    event RandomWordsRequested(uint256 indexed requestId, address indexed requester, uint32 numWords);
    event RandomWordsFulfilled(uint256 indexed requestId, uint256[] randomWords);

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32,
        uint32 numWords
    ) external returns (uint256 requestId) {
        requestId = ++requestCounter;
        pendingRequests[requestId] = PendingRequest({
            requester: msg.sender,
            numWords: numWords,
            fulfilled: false
        });
        emit RandomWordsRequested(requestId, msg.sender, numWords);
    }

    function fulfillRequest(uint256 requestId, uint256[] memory randomWords) public {
        PendingRequest storage pending = pendingRequests[requestId];
        require(pending.requester != address(0), "ManualVRF: unknown request");
        require(!pending.fulfilled, "ManualVRF: fulfilled");
        require(randomWords.length == pending.numWords, "ManualVRF: wrong words");

        pending.fulfilled = true;

        (bool success,) = pending.requester.call(
            abi.encodeWithSignature("rawFulfillRandomWords(uint256,uint256[])", requestId, randomWords)
        );
        require(success, "ManualVRF: callback failed");
        emit RandomWordsFulfilled(requestId, randomWords);
    }

    function fulfillRequestWithWord(uint256 requestId, uint256 randomWord) external {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;
        fulfillRequest(requestId, randomWords);
    }
}
