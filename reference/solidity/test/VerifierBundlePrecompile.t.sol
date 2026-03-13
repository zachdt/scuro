// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { Groth16ProofCodec } from "../src/libraries/Groth16ProofCodec.sol";
import { ScuroGroth16VerifierPrecompile } from "../src/libraries/ScuroGroth16VerifierPrecompile.sol";
import { BlackjackVerifierBundle } from "../src/verifiers/BlackjackVerifierBundle.sol";
import { LaunchVerificationKeyHashes } from "../src/verifiers/LaunchVerificationKeyHashes.sol";
import { PokerVerifierBundle } from "../src/verifiers/PokerVerifierBundle.sol";
import { BlackjackActionResolveVerifier } from "../src/verifiers/generated/BlackjackActionResolveVerifier.sol";
import { BlackjackInitialDealVerifier } from "../src/verifiers/generated/BlackjackInitialDealVerifier.sol";
import { BlackjackShowdownVerifier } from "../src/verifiers/generated/BlackjackShowdownVerifier.sol";
import { PokerDrawResolveVerifier } from "../src/verifiers/generated/PokerDrawResolveVerifier.sol";
import { PokerInitialDealVerifier } from "../src/verifiers/generated/PokerInitialDealVerifier.sol";
import { PokerShowdownVerifier } from "../src/verifiers/generated/PokerShowdownVerifier.sol";
import { MockGroth16VerifierPrecompile } from "./helpers/MockGroth16VerifierPrecompile.sol";
import { ZkFixtureLoader } from "./helpers/ZkFixtureLoader.sol";
import { IBlackjackVerifierBundle } from "../src/interfaces/IBlackjackVerifierBundle.sol";
import { IPokerVerifierBundle } from "../src/interfaces/IPokerVerifierBundle.sol";

contract VerifierBundlePrecompileTest is ZkFixtureLoader {
    address internal constant PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000000800;

    PokerVerifierBundle internal pokerBundle;
    BlackjackVerifierBundle internal blackjackBundle;

    function setUp() public {
        pokerBundle = new PokerVerifierBundle(
            address(this),
            LaunchVerificationKeyHashes.POKER_INITIAL_DEAL_VK_HASH,
            LaunchVerificationKeyHashes.POKER_DRAW_VK_HASH,
            LaunchVerificationKeyHashes.POKER_SHOWDOWN_VK_HASH,
            address(new PokerInitialDealVerifier()),
            address(new PokerDrawResolveVerifier()),
            address(new PokerShowdownVerifier())
        );

        blackjackBundle = new BlackjackVerifierBundle(
            address(this),
            LaunchVerificationKeyHashes.BLACKJACK_INITIAL_DEAL_VK_HASH,
            LaunchVerificationKeyHashes.BLACKJACK_ACTION_VK_HASH,
            LaunchVerificationKeyHashes.BLACKJACK_SHOWDOWN_VK_HASH,
            address(new BlackjackInitialDealVerifier()),
            address(new BlackjackActionResolveVerifier()),
            address(new BlackjackShowdownVerifier())
        );
    }

    function test_PokerBundleReturnsFalseForInvalidProofStatus() public {
        MockGroth16VerifierPrecompile precompile = _installPrecompile();
        precompile.setForcedStatus(LaunchVerificationKeyHashes.POKER_INITIAL_DEAL_VK_HASH, 1);

        PokerInitialDealFixture memory fixture = _loadPokerInitialDealFixture();
        IPokerVerifierBundle.InitialDealPublicInputs memory inputs = IPokerVerifierBundle.InitialDealPublicInputs({
            gameId: 1,
            handNumber: 1,
            handNonce: uint256(fixture.handNonce),
            deckCommitment: uint256(fixture.deckCommitment),
            handCommitments: [uint256(fixture.handCommitments[0]), uint256(fixture.handCommitments[1])],
            encryptionKeyCommitments: [
                uint256(fixture.encryptionKeyCommitments[0]), uint256(fixture.encryptionKeyCommitments[1])
            ],
            ciphertextRefs: [uint256(fixture.ciphertextRefs[0]), uint256(fixture.ciphertextRefs[1])]
        });

        assertFalse(pokerBundle.verifyInitialDeal(fixture.proof, inputs));
    }

    function test_PokerBundleTreatsStatusValidAsSuccess() public {
        MockGroth16VerifierPrecompile precompile = _installPrecompile();
        precompile.setForcedResponse(LaunchVerificationKeyHashes.POKER_INITIAL_DEAL_VK_HASH, 0, false);

        PokerInitialDealFixture memory fixture = _loadPokerInitialDealFixture();
        IPokerVerifierBundle.InitialDealPublicInputs memory inputs = IPokerVerifierBundle.InitialDealPublicInputs({
            gameId: 1,
            handNumber: 1,
            handNonce: uint256(fixture.handNonce),
            deckCommitment: uint256(fixture.deckCommitment),
            handCommitments: [uint256(fixture.handCommitments[0]), uint256(fixture.handCommitments[1])],
            encryptionKeyCommitments: [
                uint256(fixture.encryptionKeyCommitments[0]), uint256(fixture.encryptionKeyCommitments[1])
            ],
            ciphertextRefs: [uint256(fixture.ciphertextRefs[0]), uint256(fixture.ciphertextRefs[1])]
        });

        assertTrue(pokerBundle.verifyInitialDeal(fixture.proof, inputs));
    }

    function test_BlackjackBundleRevertsForStructuredPrecompileErrors() public {
        MockGroth16VerifierPrecompile precompile = _installPrecompile();
        precompile.setForcedStatus(LaunchVerificationKeyHashes.BLACKJACK_INITIAL_DEAL_VK_HASH, 2);

        BlackjackInitialDealFixture memory fixture = _loadBlackjackInitialDealFixture();
        IBlackjackVerifierBundle.InitialDealPublicInputs memory inputs = IBlackjackVerifierBundle.InitialDealPublicInputs({
            sessionId: 1,
            handNonce: uint256(fixture.handNonce),
            deckCommitment: uint256(fixture.deckCommitment),
            playerStateCommitment: uint256(fixture.playerStateCommitment),
            dealerStateCommitment: uint256(fixture.dealerStateCommitment),
            playerKeyCommitment: uint256(fixture.playerKeyCommitment),
            playerCiphertextRef: uint256(fixture.playerCiphertextRef),
            dealerCiphertextRef: uint256(fixture.dealerCiphertextRef),
            dealerUpValue: fixture.dealerVisibleValue,
            handCount: fixture.handCount,
            activeHandIndex: fixture.activeHandIndex,
            payout: fixture.payout,
            immediateResultCode: fixture.immediateResultCode,
            handValues: fixture.handValues,
            softMask: fixture.softMask,
            handStatuses: [
                uint256(fixture.handStatuses[0]),
                uint256(fixture.handStatuses[1]),
                uint256(fixture.handStatuses[2]),
                uint256(fixture.handStatuses[3])
            ],
            allowedActionMasks: [
                uint256(fixture.allowedActionMasks[0]),
                uint256(fixture.allowedActionMasks[1]),
                uint256(fixture.allowedActionMasks[2]),
                uint256(fixture.allowedActionMasks[3])
            ]
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                ScuroGroth16VerifierPrecompile.PrecompileVerificationError.selector,
                LaunchVerificationKeyHashes.BLACKJACK_INITIAL_DEAL_VK_HASH,
                uint32(2)
            )
        );
        blackjackBundle.verifyInitialDeal(fixture.proof, inputs);
    }

    function test_FactoryInjectedHashesMatchLaunchConstants() public view {
        assertEq(pokerBundle.initialDealVkHash(), LaunchVerificationKeyHashes.POKER_INITIAL_DEAL_VK_HASH);
        assertEq(pokerBundle.drawVkHash(), LaunchVerificationKeyHashes.POKER_DRAW_VK_HASH);
        assertEq(pokerBundle.showdownVkHash(), LaunchVerificationKeyHashes.POKER_SHOWDOWN_VK_HASH);
        assertEq(blackjackBundle.initialDealVkHash(), LaunchVerificationKeyHashes.BLACKJACK_INITIAL_DEAL_VK_HASH);
        assertEq(blackjackBundle.actionVkHash(), LaunchVerificationKeyHashes.BLACKJACK_ACTION_VK_HASH);
        assertEq(blackjackBundle.showdownVkHash(), LaunchVerificationKeyHashes.BLACKJACK_SHOWDOWN_VK_HASH);
    }

    function _installPrecompile() internal returns (MockGroth16VerifierPrecompile precompile) {
        MockGroth16VerifierPrecompile impl = new MockGroth16VerifierPrecompile();
        vm.etch(PRECOMPILE_ADDRESS, address(impl).code);
        precompile = MockGroth16VerifierPrecompile(PRECOMPILE_ADDRESS);
    }
}
