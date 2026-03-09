// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../ProtocolSettlement.sol";
import "../GameEngineRegistry.sol";
import "../engines/NumberPickerEngine.sol";

contract NumberPickerAdapter is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    ProtocolSettlement public immutable settlement;
    GameEngineRegistry public immutable registry;
    NumberPickerEngine public immutable engine;

    mapping(uint256 => bool) public requestSettled;

    event PlayFinalized(
        uint256 indexed requestId,
        address indexed player,
        uint256 wager,
        uint256 payout,
        bool isWin
    );

    constructor(address admin, address settlementAddress, address registryAddress, address engineAddress) {
        settlement = ProtocolSettlement(settlementAddress);
        registry = GameEngineRegistry(registryAddress);
        engine = NumberPickerEngine(engineAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    function play(uint256 wager, uint256 selection, bytes32 playRef) external returns (uint256 requestId) {
        require(registry.isRegisteredForSolo(address(engine)), "NumberPickerAdapter: engine inactive");
        settlement.burnPlayerWager(msg.sender, wager);
        requestId = engine.requestPlay(msg.sender, wager, selection, playRef);
        _finalize(requestId);
    }

    function finalize(uint256 requestId) external {
        _finalize(requestId);
    }

    function _finalize(uint256 requestId) internal {
        require(!requestSettled[requestId], "NumberPickerAdapter: settled");
        (
            address player,
            uint256 wager,
            ,
            ,
            uint256 payout,
            bool isWin,
            bool fulfilled
        ) = engine.getOutcome(requestId);
        require(fulfilled, "NumberPickerAdapter: pending");

        requestSettled[requestId] = true;
        if (payout > 0) {
            settlement.mintPlayerReward(player, payout);
        }
        settlement.accrueCreatorForEngine(address(engine), wager);
        emit PlayFinalized(requestId, player, wager, payout, isWin);
    }
}
