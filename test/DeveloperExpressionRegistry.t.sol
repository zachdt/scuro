// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeveloperExpressionRegistry} from "../src/DeveloperExpressionRegistry.sol";

contract DeveloperExpressionRegistryTest is Test {
    DeveloperExpressionRegistry internal expressionRegistry;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    bytes32 internal constant NUMBER_PICKER_TYPE = keccak256("NUMBER_PICKER");

    function setUp() public {
        expressionRegistry = new DeveloperExpressionRegistry(address(this));
    }

    function test_PermissionlessMintStoresMetadataAndUri() public {
        vm.prank(alice);
        uint256 tokenId =
            expressionRegistry.mintExpression(NUMBER_PICKER_TYPE, keccak256("expr-1"), "ipfs://number-picker");

        DeveloperExpressionRegistry.ExpressionMetadata memory metadata = expressionRegistry.getExpressionMetadata(tokenId);
        assertEq(tokenId, 1);
        assertEq(expressionRegistry.ownerOf(tokenId), alice);
        assertEq(metadata.engineType, NUMBER_PICKER_TYPE);
        assertEq(metadata.expressionHash, keccak256("expr-1"));
        assertEq(metadata.originalMinter, alice);
        assertTrue(metadata.active);
        assertEq(expressionRegistry.tokenURI(tokenId), "ipfs://number-picker");
    }

    function test_TransferKeepsMetadataStable() public {
        vm.prank(alice);
        uint256 tokenId =
            expressionRegistry.mintExpression(NUMBER_PICKER_TYPE, keccak256("expr-1"), "ipfs://number-picker");

        vm.prank(alice);
        expressionRegistry.transferFrom(alice, bob, tokenId);

        DeveloperExpressionRegistry.ExpressionMetadata memory metadata = expressionRegistry.getExpressionMetadata(tokenId);
        assertEq(expressionRegistry.ownerOf(tokenId), bob);
        assertEq(metadata.originalMinter, alice);
        assertEq(metadata.expressionHash, keccak256("expr-1"));
    }

    function test_AdminCanDeactivateAndCompatibilityReflectsState() public {
        vm.prank(alice);
        uint256 tokenId =
            expressionRegistry.mintExpression(NUMBER_PICKER_TYPE, keccak256("expr-1"), "ipfs://number-picker");

        assertTrue(expressionRegistry.isExpressionCompatible(NUMBER_PICKER_TYPE, tokenId));

        expressionRegistry.setExpressionActive(tokenId, false);

        DeveloperExpressionRegistry.ExpressionMetadata memory metadata = expressionRegistry.getExpressionMetadata(tokenId);
        assertFalse(metadata.active);
        assertFalse(expressionRegistry.isExpressionCompatible(NUMBER_PICKER_TYPE, tokenId));
    }
}
