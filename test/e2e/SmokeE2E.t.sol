// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { DeveloperRewards } from "../../src/DeveloperRewards.sol";
import { SlotMachineEngine } from "../../src/engines/SlotMachineEngine.sol";
import { BaseE2ETest } from "./BaseE2E.t.sol";

contract SmokeE2ETest is BaseE2ETest {
    function test_WiringAndCatalogBootstrap() public view {
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(settlement)));
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(developerRewards)));
        assertTrue(developerRewards.hasRole(developerRewards.SETTLEMENT_ROLE(), address(settlement)));
        assertTrue(catalog.isLaunchableController(address(numberPickerAdapter)));
        assertTrue(catalog.isLaunchableController(address(slotMachineController)));
        assertTrue(catalog.isAuthorizedControllerForEngine(address(numberPickerAdapter), address(numberPickerEngine)));
        assertTrue(catalog.isAuthorizedControllerForEngine(address(slotMachineController), address(slotMachineEngine)));
        assertEq(expressionRegistry.ownerOf(numberPickerExpressionTokenId), soloDeveloper.addr);
        assertEq(expressionRegistry.ownerOf(slotMachineExpressionTokenId), soloDeveloper.addr);
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)));
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)));
    }

    function test_MinimalGovernanceFlow() public {
        _executeGovernanceProposal(
            address(developerRewards),
            abi.encodeCall(DeveloperRewards.setEpochDuration, (14 days)),
            "smoke-update-epoch-duration"
        );
        assertEq(developerRewards.epochDuration(), 14 days);
    }

    function test_MinimalSoloPlayFlow() public {
        _approveSettlement(player1, 100 ether);
        vm.prank(player1.addr);
        uint256 requestId =
            numberPickerAdapter.play(100 ether, 25, keccak256("smoke-solo"), numberPickerExpressionTokenId);

        (, uint256 wager,,,,, bool fulfilled) = numberPickerEngine.getOutcome(requestId);
        assertTrue(fulfilled);
        assertEq(wager, 100 ether);
        _assertDeveloperAccrual(soloDeveloper.addr, 1, 5 ether);
        assertTrue(numberPickerAdapter.requestSettled(requestId));
        assertEq(numberPickerAdapter.requestExpressionTokenId(requestId), numberPickerExpressionTokenId);
    }

    function test_MinimalSlotPlayFlow() public {
        _approveSettlement(player1, 100 ether);

        vm.prank(player1.addr);
        uint256 spinId = slotMachineController.spin(100 ether, 1, keccak256("smoke-slot"), slotMachineExpressionTokenId);

        SlotMachineEngine.Spin memory spinData = slotMachineEngine.getSpin(spinId);
        SlotMachineEngine.SpinResult memory result = slotMachineEngine.getSpinResult(spinId);
        assertTrue(spinData.resolved);
        assertEq(spinData.finalPayout, result.totalPayout);
        assertTrue(slotMachineController.spinSettled(spinId));
        assertEq(slotMachineController.spinExpressionTokenId(spinId), slotMachineExpressionTokenId);
        _assertDeveloperAccrual(soloDeveloper.addr, 1, 5 ether);
    }

}
