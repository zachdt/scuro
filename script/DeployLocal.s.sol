// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import "../src/ScuroToken.sol";
import "../src/ScuroStakingToken.sol";
import "../src/ScuroGovernor.sol";
import "../src/GameEngineRegistry.sol";
import "../src/CreatorRewards.sol";
import "../src/ProtocolSettlement.sol";
import "../src/controllers/TournamentController.sol";
import "../src/controllers/PvPController.sol";
import "../src/controllers/NumberPickerAdapter.sol";
import "../src/engines/NumberPickerEngine.sol";
import "../src/engines/SingleDraw2To7Engine.sol";
import "../src/mocks/VRFCoordinatorMock.sol";

contract DeployLocal is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address admin = vm.addr(deployerPrivateKey);

        ScuroToken token = new ScuroToken(admin);
        ScuroStakingToken stakingToken = new ScuroStakingToken(address(token));

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        TimelockController timelock = new TimelockController(1, proposers, executors, admin);
        ScuroGovernor governor = new ScuroGovernor(stakingToken, timelock, 1, 45818, 1 ether);

        GameEngineRegistry registry = new GameEngineRegistry(admin);
        CreatorRewards creatorRewards = new CreatorRewards(admin, address(token), 7 days);
        ProtocolSettlement settlement =
            new ProtocolSettlement(admin, address(token), address(registry), address(creatorRewards));
        TournamentController tournamentController =
            new TournamentController(admin, address(settlement), address(registry));
        PvPController pvpController = new PvPController(admin, address(settlement), address(registry));

        VRFCoordinatorMock vrfCoordinator = new VRFCoordinatorMock();
        NumberPickerEngine numberPickerEngine = new NumberPickerEngine(admin, address(vrfCoordinator));
        NumberPickerAdapter numberPickerAdapter =
            new NumberPickerAdapter(admin, address(settlement), address(registry), address(numberPickerEngine));
        SingleDraw2To7Engine pokerEngine = new SingleDraw2To7Engine();

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(creatorRewards));
        creatorRewards.grantRole(creatorRewards.SETTLEMENT_ROLE(), address(settlement));
        settlement.setControllerAuthorization(address(tournamentController), true);
        settlement.setControllerAuthorization(address(pvpController), true);
        settlement.setControllerAuthorization(address(numberPickerAdapter), true);
        numberPickerEngine.grantRole(numberPickerEngine.ADAPTER_ROLE(), address(numberPickerAdapter));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        console.log("ScuroToken", address(token));
        console.log("ScuroStakingToken", address(stakingToken));
        console.log("TimelockController", address(timelock));
        console.log("ScuroGovernor", address(governor));
        console.log("GameEngineRegistry", address(registry));
        console.log("CreatorRewards", address(creatorRewards));
        console.log("ProtocolSettlement", address(settlement));
        console.log("TournamentController", address(tournamentController));
        console.log("PvPController", address(pvpController));
        console.log("VRFCoordinatorMock", address(vrfCoordinator));
        console.log("NumberPickerEngine", address(numberPickerEngine));
        console.log("NumberPickerAdapter", address(numberPickerAdapter));
        console.log("SingleDraw2To7Engine", address(pokerEngine));

        vm.stopBroadcast();
    }
}
