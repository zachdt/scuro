// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { TimelockController } from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import { CreatorRewards } from "../src/CreatorRewards.sol";
import { GameEngineRegistry } from "../src/GameEngineRegistry.sol";
import { ProtocolSettlement } from "../src/ProtocolSettlement.sol";
import { ScuroGovernor } from "../src/ScuroGovernor.sol";
import { ScuroStakingToken } from "../src/ScuroStakingToken.sol";
import { ScuroToken } from "../src/ScuroToken.sol";
import { BlackjackController } from "../src/controllers/BlackjackController.sol";
import { NumberPickerAdapter } from "../src/controllers/NumberPickerAdapter.sol";
import { PvPController } from "../src/controllers/PvPController.sol";
import { TournamentController } from "../src/controllers/TournamentController.sol";
import { NumberPickerEngine } from "../src/engines/NumberPickerEngine.sol";
import { SingleDeckBlackjackEngine } from "../src/engines/SingleDeckBlackjackEngine.sol";
import { SingleDraw2To7Engine } from "../src/engines/SingleDraw2To7Engine.sol";
import { VRFCoordinatorMock } from "../src/mocks/VRFCoordinatorMock.sol";
import { BlackjackVerifierBundle } from "../src/verifiers/BlackjackVerifierBundle.sol";
import { PokerVerifierBundle } from "../src/verifiers/PokerVerifierBundle.sol";
import { BlackjackActionResolveVerifier } from "../src/verifiers/generated/BlackjackActionResolveVerifier.sol";
import { BlackjackInitialDealVerifier } from "../src/verifiers/generated/BlackjackInitialDealVerifier.sol";
import { BlackjackShowdownVerifier } from "../src/verifiers/generated/BlackjackShowdownVerifier.sol";
import { PokerDrawResolveVerifier } from "../src/verifiers/generated/PokerDrawResolveVerifier.sol";
import { PokerInitialDealVerifier } from "../src/verifiers/generated/PokerInitialDealVerifier.sol";
import { PokerShowdownVerifier } from "../src/verifiers/generated/PokerShowdownVerifier.sol";

contract DeployLocal is Script {
    address internal constant PLAYER1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant PLAYER2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal constant SOLO_CREATOR = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address internal constant POKER_CREATOR = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
    uint256 internal constant PLAYER_FUNDS = 10_000 ether;
    uint256 internal constant CREATOR_FUNDS = 1_000 ether;

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

        PokerInitialDealVerifier pokerInitialDealVerifier = new PokerInitialDealVerifier();
        PokerDrawResolveVerifier pokerDrawResolveVerifier = new PokerDrawResolveVerifier();
        PokerShowdownVerifier pokerShowdownVerifier = new PokerShowdownVerifier();
        PokerVerifierBundle pokerVerifierBundle = new PokerVerifierBundle(
            admin, address(pokerInitialDealVerifier), address(pokerDrawResolveVerifier), address(pokerShowdownVerifier)
        );
        SingleDraw2To7Engine pokerEngine = new SingleDraw2To7Engine(admin);

        BlackjackInitialDealVerifier blackjackInitialDealVerifier = new BlackjackInitialDealVerifier();
        BlackjackActionResolveVerifier blackjackActionResolveVerifier = new BlackjackActionResolveVerifier();
        BlackjackShowdownVerifier blackjackShowdownVerifier = new BlackjackShowdownVerifier();
        BlackjackVerifierBundle blackjackVerifierBundle = new BlackjackVerifierBundle(
            admin,
            address(blackjackInitialDealVerifier),
            address(blackjackActionResolveVerifier),
            address(blackjackShowdownVerifier)
        );
        SingleDeckBlackjackEngine blackjackEngine =
            new SingleDeckBlackjackEngine(admin, address(blackjackVerifierBundle), 60);
        BlackjackController blackjackController =
            new BlackjackController(admin, address(settlement), address(registry), address(blackjackEngine));

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(creatorRewards));
        creatorRewards.grantRole(creatorRewards.SETTLEMENT_ROLE(), address(settlement));
        creatorRewards.grantRole(creatorRewards.EPOCH_MANAGER_ROLE(), address(timelock));
        settlement.setControllerAuthorization(address(tournamentController), true);
        settlement.setControllerAuthorization(address(pvpController), true);
        settlement.setControllerAuthorization(address(numberPickerAdapter), true);
        settlement.setControllerAuthorization(address(blackjackController), true);
        numberPickerEngine.grantRole(numberPickerEngine.ADAPTER_ROLE(), address(numberPickerAdapter));
        pokerEngine.grantRole(pokerEngine.CONTROLLER_ROLE(), address(tournamentController));
        pokerEngine.grantRole(pokerEngine.CONTROLLER_ROLE(), address(pvpController));
        blackjackEngine.grantRole(blackjackEngine.CONTROLLER_ROLE(), address(blackjackController));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        registry.registerEngine(
            address(numberPickerEngine),
            GameEngineRegistry.EngineMetadata({
                engineType: numberPickerEngine.ENGINE_TYPE(),
                creator: SOLO_CREATOR,
                verifier: address(0),
                configHash: keccak256("number-picker-auto"),
                creatorRateBps: 500,
                active: true,
                supportsTournament: false,
                supportsPvP: false,
                supportsSolo: true
            })
        );

        registry.registerEngine(
            address(pokerEngine),
            GameEngineRegistry.EngineMetadata({
                engineType: pokerEngine.ENGINE_TYPE(),
                creator: POKER_CREATOR,
                verifier: address(pokerVerifierBundle),
                configHash: keccak256("single-draw-2-7"),
                creatorRateBps: 1000,
                active: true,
                supportsTournament: true,
                supportsPvP: true,
                supportsSolo: false
            })
        );

        registry.registerEngine(
            address(blackjackEngine),
            GameEngineRegistry.EngineMetadata({
                engineType: blackjackEngine.ENGINE_TYPE(),
                creator: SOLO_CREATOR,
                verifier: address(blackjackVerifierBundle),
                configHash: keccak256("single-deck-blackjack-zk"),
                creatorRateBps: 500,
                active: true,
                supportsTournament: false,
                supportsPvP: false,
                supportsSolo: true
            })
        );

        token.mint(PLAYER1, PLAYER_FUNDS);
        token.mint(PLAYER2, PLAYER_FUNDS);
        token.mint(admin, PLAYER_FUNDS);
        token.mint(SOLO_CREATOR, CREATOR_FUNDS);
        token.mint(POKER_CREATOR, CREATOR_FUNDS);

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
        console.log("PokerVerifierBundle", address(pokerVerifierBundle));
        console.log("SingleDraw2To7Engine", address(pokerEngine));
        console.log("BlackjackVerifierBundle", address(blackjackVerifierBundle));
        console.log("SingleDeckBlackjackEngine", address(blackjackEngine));
        console.log("BlackjackController", address(blackjackController));
        console.log("Admin", admin);
        console.log("Player1", PLAYER1);
        console.log("Player2", PLAYER2);
        console.log("SoloCreator", SOLO_CREATOR);
        console.log("PokerCreator", POKER_CREATOR);

        vm.stopBroadcast();
    }
}
