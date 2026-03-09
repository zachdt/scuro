// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract NumberPickerEngine is AccessControl {
    bytes32 public constant ADAPTER_ROLE = keccak256("ADAPTER_ROLE");
    bytes32 public constant ENGINE_TYPE = keccak256("NUMBER_PICKER");

    struct PlayRequest {
        address player;
        uint256 wager;
        uint256 selection;
        bytes32 playRef;
        uint256 rollResult;
        uint256 payout;
        bool isWin;
        bool fulfilled;
    }

    address public vrfCoordinator;
    uint256 public totalGamesPlayed;
    uint256 public totalWagers;
    uint256 public totalPayouts;

    mapping(uint256 => PlayRequest) public playRequests;

    event PlayRequested(
        uint256 indexed requestId,
        address indexed player,
        bytes32 indexed playRef,
        uint256 wager,
        uint256 selection
    );
    event PlayResolved(
        uint256 indexed requestId,
        address indexed player,
        uint256 rollResult,
        uint256 payout,
        bool isWin
    );

    constructor(address admin, address vrfCoordinatorAddress) {
        vrfCoordinator = vrfCoordinatorAddress;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADAPTER_ROLE, admin);
    }

    function engineType() external pure returns (bytes32) {
        return ENGINE_TYPE;
    }

    function setVRFCoordinator(address newCoordinator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        vrfCoordinator = newCoordinator;
    }

    function requestPlay(
        address player,
        uint256 wager,
        uint256 selection,
        bytes32 playRef
    ) external onlyRole(ADAPTER_ROLE) returns (uint256 requestId) {
        require(selection >= 1 && selection <= 99, "NumberPicker: invalid selection");
        require(wager > 0, "NumberPicker: invalid wager");

        requestId = _getNextRequestId();
        playRequests[requestId] = PlayRequest({
            player: player,
            wager: wager,
            selection: selection,
            playRef: playRef,
            rollResult: 0,
            payout: 0,
            isWin: false,
            fulfilled: false
        });

        totalGamesPlayed += 1;
        totalWagers += wager;

        emit PlayRequested(requestId, player, playRef, wager, selection);

        uint256 actualId = _requestRandomness();
        require(actualId == requestId, "NumberPicker: request mismatch");
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        require(msg.sender == vrfCoordinator, "NumberPicker: bad coordinator");
        PlayRequest storage playRequest = playRequests[requestId];
        require(playRequest.player != address(0), "NumberPicker: unknown request");
        require(!playRequest.fulfilled, "NumberPicker: fulfilled");

        uint256 rollResult = (randomWords[0] % 100) + 1;
        bool isWin = rollResult > playRequest.selection;
        uint256 payout = 0;
        if (isWin) {
            payout = (playRequest.wager * 100) / playRequest.selection;
            totalPayouts += payout;
        }

        playRequest.rollResult = rollResult;
        playRequest.payout = payout;
        playRequest.isWin = isWin;
        playRequest.fulfilled = true;

        emit PlayResolved(requestId, playRequest.player, rollResult, payout, isWin);
    }

    function getOutcome(uint256 requestId)
        external
        view
        returns (
            address player,
            uint256 wager,
            uint256 selection,
            uint256 rollResult,
            uint256 payout,
            bool isWin,
            bool fulfilled
        )
    {
        PlayRequest memory playRequest = playRequests[requestId];
        return (
            playRequest.player,
            playRequest.wager,
            playRequest.selection,
            playRequest.rollResult,
            playRequest.payout,
            playRequest.isWin,
            playRequest.fulfilled
        );
    }

    function _getNextRequestId() internal view returns (uint256) {
        (bool success, bytes memory data) = vrfCoordinator.staticcall(abi.encodeWithSignature("requestCounter()"));
        require(success, "NumberPicker: counter failed");
        return abi.decode(data, (uint256)) + 1;
    }

    function _requestRandomness() internal returns (uint256) {
        (bool success, bytes memory data) = vrfCoordinator.call(
            abi.encodeWithSignature(
                "requestRandomWords(bytes32,uint64,uint16,uint32,uint32)",
                bytes32(0),
                uint64(0),
                uint16(3),
                uint32(100000),
                uint32(1)
            )
        );
        require(success, "NumberPicker: vrf failed");
        return abi.decode(data, (uint256));
    }
}
