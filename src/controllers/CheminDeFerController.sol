// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {GameCatalog} from "../GameCatalog.sol";
import {ProtocolSettlement} from "../ProtocolSettlement.sol";
import {BaccaratTypes} from "../libraries/BaccaratTypes.sol";
import {ICheminDeFerEngine} from "../interfaces/ICheminDeFerEngine.sol";

/// @title Automated chemin de fer controller
/// @notice Runs banker-opened baccarat tables with permissionless takers and shared settlement.
contract CheminDeFerController is ReentrancyGuard {
    uint256 public constant BANKER_RISK_PER_PLAYER_WAD = 1_027_677_102_818_402_306;

    struct Table {
        address banker;
        uint256 bankerEscrow;
        uint256 joinDeadline;
        uint256 totalPlayerTake;
        uint256 matchedBankerRisk;
        uint256 unmatchedBankerRefund;
        uint256 expressionTokenId;
        bytes32 playRef;
        bool closed;
        bool settled;
    }

    ProtocolSettlement internal immutable SETTLEMENT;
    GameCatalog internal immutable CATALOG;
    ICheminDeFerEngine internal immutable ENGINE;
    uint256 public immutable JOIN_WINDOW;

    uint256 public nextTableId = 1;

    mapping(uint256 => Table) public tables;
    mapping(uint256 => address[]) internal tableTakers;
    mapping(uint256 => mapping(address => uint256)) internal takerAmounts;

    event TableOpened(
        uint256 indexed tableId,
        address indexed banker,
        uint256 indexed expressionTokenId,
        uint256 bankerEscrow,
        uint256 joinDeadline,
        bytes32 playRef
    );
    event TableTaken(uint256 indexed tableId, address indexed taker, uint256 amount, uint256 totalTake);
    event TableClosed(uint256 indexed tableId, address indexed caller, uint256 requestId);
    event TableCanceled(uint256 indexed tableId, address indexed banker, uint256 refund);
    event TableSettled(
        uint256 indexed tableId,
        address indexed banker,
        uint256 indexed expressionTokenId,
        BaccaratTypes.BaccaratOutcome outcome,
        uint256 matchedExposure
    );

    constructor(address settlementAddress, address catalogAddress, address engineAddress, uint256 joinWindow) {
        SETTLEMENT = ProtocolSettlement(settlementAddress);
        CATALOG = GameCatalog(catalogAddress);
        ENGINE = ICheminDeFerEngine(engineAddress);
        JOIN_WINDOW = joinWindow;
    }

    function settlement() public view returns (ProtocolSettlement) {
        return SETTLEMENT;
    }

    function catalog() public view returns (GameCatalog) {
        return CATALOG;
    }

    function engine() public view returns (ICheminDeFerEngine) {
        return ENGINE;
    }

    function getTakers(uint256 tableId) external view returns (address[] memory) {
        return tableTakers[tableId];
    }

    function getTakerAmount(uint256 tableId, address taker) external view returns (uint256) {
        return takerAmounts[tableId][taker];
    }

    function playerTakeCap(uint256 bankerEscrow) public pure returns (uint256) {
        return Math.mulDiv(bankerEscrow, 1e18, BANKER_RISK_PER_PLAYER_WAD);
    }

    function matchedBankerRisk(uint256 totalPlayerTake) public pure returns (uint256) {
        return Math.mulDiv(totalPlayerTake, BANKER_RISK_PER_PLAYER_WAD, 1e18);
    }

    function openTable(uint256 bankerMaxBet, bytes32 playRef, uint256 expressionTokenId)
        external
        nonReentrant
        returns (uint256 tableId)
    {
        require(CATALOG.isLaunchableController(address(this)), "CheminDeFerController: module inactive");
        require(bankerMaxBet > 0, "CheminDeFerController: invalid banker max bet");

        SETTLEMENT.burnPlayerWager(msg.sender, bankerMaxBet);

        tableId = nextTableId++;
        tables[tableId] = Table({
            banker: msg.sender,
            bankerEscrow: bankerMaxBet,
            joinDeadline: block.timestamp + JOIN_WINDOW,
            totalPlayerTake: 0,
            matchedBankerRisk: 0,
            unmatchedBankerRefund: bankerMaxBet,
            expressionTokenId: expressionTokenId,
            playRef: playRef,
            closed: false,
            settled: false
        });

        emit TableOpened(tableId, msg.sender, expressionTokenId, bankerMaxBet, block.timestamp + JOIN_WINDOW, playRef);
    }

    function take(uint256 tableId, uint256 amount) external nonReentrant {
        require(CATALOG.isLaunchableController(address(this)), "CheminDeFerController: module inactive");
        require(amount > 0, "CheminDeFerController: invalid take");

        Table storage table = tables[tableId];
        require(table.banker != address(0), "CheminDeFerController: unknown table");
        require(!table.closed, "CheminDeFerController: closed");
        require(block.timestamp <= table.joinDeadline, "CheminDeFerController: join expired");
        require(msg.sender != table.banker, "CheminDeFerController: banker cannot take");

        uint256 maxTake = playerTakeCap(table.bankerEscrow);
        require(table.totalPlayerTake + amount <= maxTake, "CheminDeFerController: take exceeds cap");

        SETTLEMENT.burnPlayerWager(msg.sender, amount);

        if (takerAmounts[tableId][msg.sender] == 0) {
            tableTakers[tableId].push(msg.sender);
        }
        takerAmounts[tableId][msg.sender] += amount;
        table.totalPlayerTake += amount;

        emit TableTaken(tableId, msg.sender, amount, table.totalPlayerTake);

        if (table.totalPlayerTake == maxTake) {
            _closeAndRequestResolution(tableId, msg.sender);
        }
    }

    function closeTable(uint256 tableId) external nonReentrant {
        require(CATALOG.isSettlableController(address(this)), "CheminDeFerController: module inactive");
        Table storage table = tables[tableId];
        require(table.banker == msg.sender, "CheminDeFerController: not banker");
        require(table.totalPlayerTake > 0, "CheminDeFerController: no takers");
        _closeAndRequestResolution(tableId, msg.sender);
    }

    function forceCloseTable(uint256 tableId) external nonReentrant {
        require(CATALOG.isSettlableController(address(this)), "CheminDeFerController: module inactive");
        Table storage table = tables[tableId];
        require(table.banker != address(0), "CheminDeFerController: unknown table");
        require(block.timestamp > table.joinDeadline, "CheminDeFerController: join active");
        require(table.totalPlayerTake > 0, "CheminDeFerController: no takers");
        _closeAndRequestResolution(tableId, msg.sender);
    }

    function cancelTable(uint256 tableId) external nonReentrant {
        require(CATALOG.isSettlableController(address(this)), "CheminDeFerController: module inactive");
        Table storage table = tables[tableId];
        require(table.banker != address(0), "CheminDeFerController: unknown table");
        require(!table.closed, "CheminDeFerController: closed");
        require(table.totalPlayerTake == 0, "CheminDeFerController: takers present");
        require(msg.sender == table.banker || block.timestamp > table.joinDeadline, "CheminDeFerController: cancel blocked");

        table.closed = true;
        table.settled = true;

        SETTLEMENT.mintPlayerReward(table.banker, table.bankerEscrow);
        emit TableCanceled(tableId, table.banker, table.bankerEscrow);
    }

    function settle(uint256 tableId) external nonReentrant {
        require(CATALOG.isSettlableController(address(this)), "CheminDeFerController: module inactive");
        Table storage table = tables[tableId];
        require(table.banker != address(0), "CheminDeFerController: unknown table");
        require(table.closed, "CheminDeFerController: open");
        require(!table.settled, "CheminDeFerController: settled");

        (,,,,,,, BaccaratTypes.BaccaratOutcome outcome,, bool resolved,,) = ENGINE.getRound(tableId);
        require(resolved, "CheminDeFerController: pending");

        table.settled = true;

        uint256 bankerPayout = table.unmatchedBankerRefund;
        uint256 matchedExposure = table.matchedBankerRisk + table.totalPlayerTake;

        if (outcome == BaccaratTypes.BaccaratOutcome.BankerWin) {
            bankerPayout += matchedExposure;
            SETTLEMENT.mintPlayerReward(table.banker, bankerPayout);
        } else if (outcome == BaccaratTypes.BaccaratOutcome.Tie) {
            bankerPayout += table.matchedBankerRisk;
            SETTLEMENT.mintPlayerReward(table.banker, bankerPayout);
            _refundTakers(tableId);
        } else {
            if (bankerPayout > 0) {
                SETTLEMENT.mintPlayerReward(table.banker, bankerPayout);
            }
            _payWinningTakers(tableId, matchedExposure);
        }

        SETTLEMENT.accrueDeveloperForExpression(table.expressionTokenId, matchedExposure);
        emit TableSettled(tableId, table.banker, table.expressionTokenId, outcome, matchedExposure);
    }

    function _closeAndRequestResolution(uint256 tableId, address caller) internal {
        Table storage table = tables[tableId];
        require(table.banker != address(0), "CheminDeFerController: unknown table");
        require(!table.closed, "CheminDeFerController: closed");

        table.closed = true;
        table.matchedBankerRisk = matchedBankerRisk(table.totalPlayerTake);
        table.unmatchedBankerRefund = table.bankerEscrow - table.matchedBankerRisk;
        uint256 requestId = ENGINE.requestResolution(tableId, table.playRef);
        emit TableClosed(tableId, caller, requestId);
    }

    function _refundTakers(uint256 tableId) internal {
        address[] storage takers = tableTakers[tableId];
        for (uint256 i = 0; i < takers.length; i++) {
            SETTLEMENT.mintPlayerReward(takers[i], takerAmounts[tableId][takers[i]]);
        }
    }

    function _payWinningTakers(uint256 tableId, uint256 payoutPool) internal {
        address[] storage takers = tableTakers[tableId];
        uint256 totalTake = tables[tableId].totalPlayerTake;
        uint256 distributed = 0;

        for (uint256 i = 0; i < takers.length; i++) {
            uint256 payout;
            if (i + 1 == takers.length) {
                payout = payoutPool - distributed;
            } else {
                payout = Math.mulDiv(payoutPool, takerAmounts[tableId][takers[i]], totalTake);
                distributed += payout;
            }

            if (payout > 0) {
                SETTLEMENT.mintPlayerReward(takers[i], payout);
            }
        }
    }
}
