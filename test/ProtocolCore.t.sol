// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {CreatorRewards} from "../src/CreatorRewards.sol";
import {GameEngineRegistry} from "../src/GameEngineRegistry.sol";
import {ProtocolSettlement} from "../src/ProtocolSettlement.sol";
import {ScuroGovernor} from "../src/ScuroGovernor.sol";
import {ScuroStakingToken} from "../src/ScuroStakingToken.sol";
import {ScuroToken} from "../src/ScuroToken.sol";

contract ProtocolCoreTest is Test {
    ScuroToken internal token;
    ScuroStakingToken internal stakingToken;
    TimelockController internal timelock;
    ScuroGovernor internal governor;
    GameEngineRegistry internal registry;
    CreatorRewards internal creatorRewards;
    ProtocolSettlement internal settlement;

    address internal alice = address(0xA11CE);
    address internal controller = address(0xC0DE);

    function setUp() public {
        token = new ScuroToken(address(this));
        stakingToken = new ScuroStakingToken(address(token));

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(1, proposers, executors, address(this));
        governor = new ScuroGovernor(stakingToken, timelock, 1, 5, 1 ether);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        registry = new GameEngineRegistry(address(this));
        creatorRewards = new CreatorRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(address(this), address(token), address(registry), address(creatorRewards));

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(creatorRewards));
        creatorRewards.grantRole(creatorRewards.SETTLEMENT_ROLE(), address(settlement));
        creatorRewards.grantRole(creatorRewards.EPOCH_MANAGER_ROLE(), address(timelock));

        token.mint(alice, 1_000 ether);
    }

    function test_StakingChangesVotingPower() public {
        vm.startPrank(alice);
        token.approve(address(stakingToken), 100 ether);
        stakingToken.stake(100 ether);
        stakingToken.delegate(alice);
        vm.stopPrank();

        assertEq(stakingToken.balanceOf(alice), 100 ether);
        assertEq(stakingToken.getVotes(alice), 100 ether);
    }

    function test_GovernanceCanUpdateCreatorEpochDuration() public {
        vm.startPrank(alice);
        token.approve(address(stakingToken), 500 ether);
        stakingToken.stake(500 ether);
        stakingToken.delegate(alice);
        vm.stopPrank();
        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        targets[0] = address(creatorRewards);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(CreatorRewards.setEpochDuration, (14 days));
        string memory description = "update epoch duration";

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        vm.warp(block.timestamp + 2);
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(creatorRewards.epochDuration(), 14 days);
    }

    function test_UnauthorizedContractsCannotBurnMintOrAccrue() public {
        vm.startPrank(alice);
        token.approve(address(settlement), 10 ether);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert();
        settlement.burnPlayerWager(alice, 1 ether);

        vm.prank(alice);
        vm.expectRevert();
        settlement.mintPlayerReward(alice, 1 ether);

        vm.prank(alice);
        vm.expectRevert();
        settlement.accrueCreatorForEngine(address(0x1234), 1 ether);

        settlement.setControllerAuthorization(controller, true);
        vm.prank(controller);
        settlement.burnPlayerWager(alice, 1 ether);
        assertEq(token.balanceOf(alice), 999 ether);
    }
}
