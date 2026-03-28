// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface ISoloModuleDeployer {
    function deployNumberPickerModule(address catalogAddress, address settlementAddress, address vrfCoordinator)
        external
        returns (address controller, address engine, address verifier, bytes32 engineType);

    function deploySuperBaccaratModule(address catalogAddress, address settlementAddress, address vrfCoordinator)
        external
        returns (address controller, address engine, address verifier, bytes32 engineType);

    function deploySlotMachineModule(address catalogAddress, address settlementAddress, address vrfCoordinator, address admin)
        external
        returns (address controller, address engine, address verifier, bytes32 engineType);
}

interface IBlackjackModuleDeployer {
    function deployBlackjackModule(
        address catalogAddress,
        address settlementAddress,
        address coordinator,
        uint256 defaultActionWindow,
        address admin
    ) external returns (address controller, address engine, address verifier, bytes32 engineType);
}

interface IPokerModuleDeployer {
    function deployPvPModule(
        address catalogAddress,
        address settlementAddress,
        address coordinator,
        uint256 smallBlind,
        uint256 bigBlind,
        uint256 blindEscalationInterval,
        uint256 actionWindow,
        address admin
    ) external returns (address controller, address engine, address verifier, bytes32 engineType);

    function deployTournamentModule(
        address catalogAddress,
        address settlementAddress,
        address coordinator,
        uint256 smallBlind,
        uint256 bigBlind,
        uint256 blindEscalationInterval,
        uint256 actionWindow,
        address admin
    ) external returns (address controller, address engine, address verifier, bytes32 engineType);
}

interface ICheminDeFerModuleDeployer {
    function deployCheminDeFerModule(
        address catalogAddress,
        address settlementAddress,
        address vrfCoordinator,
        uint256 joinWindow
    ) external returns (address controller, address engine, address verifier, bytes32 engineType);
}
