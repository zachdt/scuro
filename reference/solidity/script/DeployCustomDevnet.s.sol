// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { TimelockController } from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import { DeveloperExpressionRegistry } from "../src/DeveloperExpressionRegistry.sol";
import { DeveloperRewards } from "../src/DeveloperRewards.sol";
import { GameCatalog } from "../src/GameCatalog.sol";
import { GameDeploymentFactory } from "../src/GameDeploymentFactory.sol";
import { ProtocolSettlement } from "../src/ProtocolSettlement.sol";
import { ScuroGovernor } from "../src/ScuroGovernor.sol";
import { ScuroStakingToken } from "../src/ScuroStakingToken.sol";
import { ScuroToken } from "../src/ScuroToken.sol";
import { ScuroVerifierRegistry } from "../src/verifiers/ScuroVerifierRegistry.sol";
import { BlackjackController } from "../src/controllers/BlackjackController.sol";
import { NumberPickerAdapter } from "../src/controllers/NumberPickerAdapter.sol";
import { PvPController } from "../src/controllers/PvPController.sol";
import { TournamentController } from "../src/controllers/TournamentController.sol";
import { NumberPickerEngine } from "../src/engines/NumberPickerEngine.sol";
import { SingleDeckBlackjackEngine } from "../src/engines/SingleDeckBlackjackEngine.sol";
import { SingleDraw2To7Engine } from "../src/engines/SingleDraw2To7Engine.sol";
import { VRFCoordinatorMock } from "../src/mocks/VRFCoordinatorMock.sol";

contract DeployCustomDevnet is Script {
    address internal constant VERIFIER_REGISTRY = 0x0000000000000000000000000000000000000801;
    address internal constant PLAYER1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant PLAYER2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal constant SOLO_DEVELOPER = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address internal constant POKER_DEVELOPER = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
    uint256 internal constant PLAYER_FUNDS = 10_000 ether;
    uint256 internal constant DEVELOPER_FUNDS = 1_000 ether;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        bool renounceVerifierRegistryRoles = vm.envOr("RENOUNCE_VERIFIER_REGISTRY_ROLES", true);

        vm.startBroadcast(deployerPrivateKey);

        address admin = vm.addr(deployerPrivateKey);
        ScuroVerifierRegistry verifierRegistry = ScuroVerifierRegistry(VERIFIER_REGISTRY);
        require(address(verifierRegistry).code.length > 0, "DeployCustomDevnet: missing registry predeploy");

        ScuroToken token = new ScuroToken(admin);
        ScuroStakingToken stakingToken = new ScuroStakingToken(address(token));

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        TimelockController timelock = new TimelockController(1, proposers, executors, admin);
        ScuroGovernor governor = new ScuroGovernor(stakingToken, timelock, 1, 45818, 1 ether);

        GameCatalog catalog = new GameCatalog(admin);
        DeveloperExpressionRegistry expressionRegistry = new DeveloperExpressionRegistry(admin);
        DeveloperRewards developerRewards = new DeveloperRewards(admin, address(token), 7 days);
        ProtocolSettlement settlement = new ProtocolSettlement(
            address(token), address(catalog), address(expressionRegistry), address(developerRewards)
        );
        GameDeploymentFactory factory = new GameDeploymentFactory(admin, address(catalog), address(settlement));

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));
        developerRewards.grantRole(developerRewards.EPOCH_MANAGER_ROLE(), address(timelock));
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(factory));

        VRFCoordinatorMock vrfCoordinator = new VRFCoordinatorMock();

        GameDeploymentFactory.NumberPickerDeployment memory numberPickerParams =
            GameDeploymentFactory.NumberPickerDeployment({
                vrfCoordinator: address(vrfCoordinator),
                configHash: keccak256("number-picker-auto"),
                developerRewardBps: 500
            });
        uint256 numberPickerModuleId;
        address numberPickerControllerAddress;
        address numberPickerEngineAddress;
        (numberPickerModuleId, numberPickerControllerAddress, numberPickerEngineAddress,) = factory.deploySoloModule(
            uint8(GameDeploymentFactory.SoloFamily.NumberPicker), abi.encode(numberPickerParams)
        );

        GameDeploymentFactory.PokerDeployment memory tournamentPokerParams = GameDeploymentFactory.PokerDeployment({
            coordinator: admin,
            smallBlind: 10,
            bigBlind: 20,
            blindEscalationInterval: 180,
            actionWindow: 60,
            configHash: keccak256("single-draw-2-7-tournament"),
            developerRewardBps: 1_000
        });
        uint256 tournamentPokerModuleId;
        address tournamentControllerAddress;
        address tournamentPokerEngineAddress;
        address tournamentPokerVerifierBundle;
        (
            tournamentPokerModuleId,
            tournamentControllerAddress,
            tournamentPokerEngineAddress,
            tournamentPokerVerifierBundle
        ) =
            factory.deployTournamentModule(
                uint8(GameDeploymentFactory.MatchFamily.PokerSingleDraw2To7), abi.encode(tournamentPokerParams)
            );

        GameDeploymentFactory.PokerDeployment memory pvpPokerParams = GameDeploymentFactory.PokerDeployment({
            coordinator: admin,
            smallBlind: 10,
            bigBlind: 20,
            blindEscalationInterval: 180,
            actionWindow: 60,
            configHash: keccak256("single-draw-2-7-pvp"),
            developerRewardBps: 1_000
        });
        uint256 pvpPokerModuleId;
        address pvpControllerAddress;
        address pvpPokerEngineAddress;
        address pvpPokerVerifierBundle;
        (pvpPokerModuleId, pvpControllerAddress, pvpPokerEngineAddress, pvpPokerVerifierBundle) = factory.deployPvPModule(
            uint8(GameDeploymentFactory.MatchFamily.PokerSingleDraw2To7), abi.encode(pvpPokerParams)
        );

        GameDeploymentFactory.BlackjackDeployment memory blackjackParams = GameDeploymentFactory.BlackjackDeployment({
            coordinator: admin,
            defaultActionWindow: 60,
            configHash: keccak256("single-deck-blackjack-zk"),
            developerRewardBps: 500
        });
        uint256 blackjackModuleId;
        address blackjackControllerAddress;
        address blackjackEngineAddress;
        address blackjackVerifierBundle;
        (blackjackModuleId, blackjackControllerAddress, blackjackEngineAddress, blackjackVerifierBundle) =
            factory.deploySoloModule(uint8(GameDeploymentFactory.SoloFamily.Blackjack), abi.encode(blackjackParams));

        NumberPickerAdapter numberPickerAdapter = NumberPickerAdapter(numberPickerControllerAddress);
        NumberPickerEngine numberPickerEngine = NumberPickerEngine(numberPickerEngineAddress);
        TournamentController tournamentController = TournamentController(tournamentControllerAddress);
        SingleDraw2To7Engine tournamentPokerEngine = SingleDraw2To7Engine(tournamentPokerEngineAddress);
        PvPController pvpController = PvPController(pvpControllerAddress);
        SingleDraw2To7Engine pvpPokerEngine = SingleDraw2To7Engine(pvpPokerEngineAddress);
        BlackjackController blackjackController = BlackjackController(blackjackControllerAddress);
        SingleDeckBlackjackEngine blackjackEngine = SingleDeckBlackjackEngine(blackjackEngineAddress);

        uint256 numberPickerExpressionTokenId = expressionRegistry.mintExpression(
            numberPickerEngine.engineType(), keccak256("number-picker-auto"), "ipfs://scuro/number-picker-auto"
        );
        uint256 blackjackExpressionTokenId = expressionRegistry.mintExpression(
            blackjackEngine.engineType(), keccak256("single-deck-blackjack-zk"), "ipfs://scuro/single-deck-blackjack-zk"
        );
        uint256 pokerExpressionTokenId = expressionRegistry.mintExpression(
            tournamentPokerEngine.engineType(), keccak256("single-draw-2-7"), "ipfs://scuro/single-draw-2-7"
        );

        expressionRegistry.transferFrom(admin, SOLO_DEVELOPER, numberPickerExpressionTokenId);
        expressionRegistry.transferFrom(admin, SOLO_DEVELOPER, blackjackExpressionTokenId);
        expressionRegistry.transferFrom(admin, POKER_DEVELOPER, pokerExpressionTokenId);
        token.mint(PLAYER1, PLAYER_FUNDS);
        token.mint(PLAYER2, PLAYER_FUNDS);
        token.mint(admin, PLAYER_FUNDS);
        token.mint(SOLO_DEVELOPER, DEVELOPER_FUNDS);
        token.mint(POKER_DEVELOPER, DEVELOPER_FUNDS);

        catalog.grantRole(catalog.DEFAULT_ADMIN_ROLE(), address(timelock));
        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(timelock));
        catalog.renounceRole(catalog.DEFAULT_ADMIN_ROLE(), admin);
        catalog.renounceRole(catalog.REGISTRAR_ROLE(), admin);
        verifierRegistry.grantRole(verifierRegistry.DEFAULT_ADMIN_ROLE(), address(timelock));
        verifierRegistry.grantRole(verifierRegistry.REGISTRAR_ROLE(), address(timelock));
        if (renounceVerifierRegistryRoles) {
            verifierRegistry.renounceRole(verifierRegistry.DEFAULT_ADMIN_ROLE(), admin);
            verifierRegistry.renounceRole(verifierRegistry.REGISTRAR_ROLE(), admin);
        }
        factory.grantRole(factory.DEFAULT_ADMIN_ROLE(), address(timelock));
        factory.grantRole(factory.DEPLOYER_ROLE(), address(timelock));
        factory.renounceRole(factory.DEFAULT_ADMIN_ROLE(), admin);
        factory.renounceRole(factory.DEPLOYER_ROLE(), admin);

        console.log("ScuroToken", address(token));
        console.log("ScuroStakingToken", address(stakingToken));
        console.log("TimelockController", address(timelock));
        console.log("ScuroGovernor", address(governor));
        console.log("GameCatalog", address(catalog));
        console.log("GameDeploymentFactory", address(factory));
        console.log("DeveloperExpressionRegistry", address(expressionRegistry));
        console.log("DeveloperRewards", address(developerRewards));
        console.log("ScuroVerifierRegistry", address(verifierRegistry));
        console.log("ProtocolSettlement", address(settlement));
        console.log("TournamentController", address(tournamentController));
        console.log("TournamentPokerEngine", address(tournamentPokerEngine));
        console.log("TournamentPokerVerifierBundle", tournamentPokerVerifierBundle);
        console.log("PvPController", address(pvpController));
        console.log("PvPPokerEngine", address(pvpPokerEngine));
        console.log("PvPPokerVerifierBundle", pvpPokerVerifierBundle);
        console.log("VRFCoordinatorMock", address(vrfCoordinator));
        console.log("NumberPickerEngine", address(numberPickerEngine));
        console.log("NumberPickerAdapter", address(numberPickerAdapter));
        console.log("BlackjackVerifierBundle", blackjackVerifierBundle);
        console.log("SingleDeckBlackjackEngine", address(blackjackEngine));
        console.log("BlackjackController", address(blackjackController));
        console.log("NumberPickerModuleId", numberPickerModuleId);
        console.log("TournamentPokerModuleId", tournamentPokerModuleId);
        console.log("PvPPokerModuleId", pvpPokerModuleId);
        console.log("BlackjackModuleId", blackjackModuleId);
        console.log("Admin", admin);
        console.log("Player1", PLAYER1);
        console.log("Player2", PLAYER2);
        console.log("SoloDeveloper", SOLO_DEVELOPER);
        console.log("PokerDeveloper", POKER_DEVELOPER);
        console.log("NumberPickerExpressionTokenId", numberPickerExpressionTokenId);
        console.log("PokerExpressionTokenId", pokerExpressionTokenId);
        console.log("BlackjackExpressionTokenId", blackjackExpressionTokenId);

        vm.stopBroadcast();
    }
}
