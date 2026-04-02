// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {FixtureLoaders} from "../../script/aws/FixtureLoaders.sol";

contract FixtureLoadersHarness is FixtureLoaders {
    function loadPokerInitialDeal() external view returns (PokerInitialDealFixture memory) {
        return _loadPokerInitialDealFixture();
    }

    function loadPokerShowdown() external view returns (PokerShowdownFixture memory) {
        return _loadPokerShowdownFixture();
    }

    function loadBlackjackInitialDeal() external view returns (BlackjackInitialDealFixture memory) {
        return _loadBlackjackInitialDealFixture();
    }

    function loadBlackjackInitialDealForSubmission() external view returns (BlackjackInitialDealFixture memory) {
        return _loadBlackjackInitialDealForSubmission();
    }

    function loadBlackjackAction() external view returns (BlackjackActionFixture memory) {
        return _loadBlackjackActionFixture();
    }

    function loadBlackjackActionForSubmission() external view returns (BlackjackActionFixture memory) {
        return _loadBlackjackActionForSubmission();
    }

    function loadBlackjackShowdown() external view returns (BlackjackShowdownFixture memory) {
        return _loadBlackjackShowdownFixture();
    }

    function loadBlackjackShowdownForSubmission() external view returns (BlackjackShowdownFixture memory) {
        return _loadBlackjackShowdownForSubmission();
    }
}
