// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {GameEngineRegistry} from "../GameEngineRegistry.sol";
import {ProtocolSettlement} from "../ProtocolSettlement.sol";
import {NumberPickerEngine} from "../engines/NumberPickerEngine.sol";

contract NumberPickerAdapter is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    ProtocolSettlement internal immutable SETTLEMENT;
    GameEngineRegistry internal immutable REGISTRY;
    NumberPickerEngine internal immutable ENGINE;

    mapping(uint256 => bool) public requestSettled;

    event PlayFinalized(
        uint256 indexed requestId,
        address indexed player,
        uint256 wager,
        uint256 payout,
        bool isWin
    );

    constructor(address admin, address settlementAddress, address registryAddress, address engineAddress) {
        SETTLEMENT = ProtocolSettlement(settlementAddress);
        REGISTRY = GameEngineRegistry(registryAddress);
        ENGINE = NumberPickerEngine(engineAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    function settlement() public view returns (ProtocolSettlement) {
        return SETTLEMENT;
    }

    function registry() public view returns (GameEngineRegistry) {
        return REGISTRY;
    }

    function engine() public view returns (NumberPickerEngine) {
        return ENGINE;
    }

    function play(uint256 wager, uint256 selection, bytes32 playRef) external returns (uint256 requestId) {
        require(REGISTRY.isRegisteredForSolo(address(ENGINE)), "NumberPickerAdapter: engine inactive");
        SETTLEMENT.burnPlayerWager(msg.sender, wager);
        requestId = ENGINE.requestPlay(msg.sender, wager, selection, playRef);
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
        ) = ENGINE.getOutcome(requestId);
        require(fulfilled, "NumberPickerAdapter: pending");

        requestSettled[requestId] = true;
        if (payout > 0) {
            SETTLEMENT.mintPlayerReward(player, payout);
        }
        SETTLEMENT.accrueCreatorForEngine(address(ENGINE), wager);
        emit PlayFinalized(requestId, player, wager, payout, isWin);
    }
}
