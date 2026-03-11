// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

library LaunchVerificationKeyHashes {
    bytes32 internal constant POKER_INITIAL_DEAL_VK_HASH =
        0x833ed812656caee88783d418ddf6d1cebd9b7856d70b47c44cd59b3d55fc5b31;
    bytes32 internal constant POKER_DRAW_VK_HASH = 0xd52c550d4b81a3176cec079ec43c1a3a8c239f324305dc2fcf5c50784ce34d06;
    bytes32 internal constant POKER_SHOWDOWN_VK_HASH =
        0xd93598d756e561a8991900b72c468bf1aeb9a89ecfe4f0728becea885d43164c;
    bytes32 internal constant BLACKJACK_INITIAL_DEAL_VK_HASH =
        0x6a6bfbb56d4b0242fda025b81ae810c1bf01669b5e1fb4418d0e088dbfc567a7;
    bytes32 internal constant BLACKJACK_ACTION_VK_HASH =
        0xd7e870e383aeae0287dc886e043a08faf6147914d22b439ba42e7d4d4a29505d;
    bytes32 internal constant BLACKJACK_SHOWDOWN_VK_HASH =
        0x0f33158026795cc64e25b5430ec06eff21f2e39eea00b36bc11f9c0654b265d2;
}
