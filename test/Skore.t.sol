// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/SkoreSBT.sol";

contract SkoreTest is Test {
    SkoreSBT skore;

    address owner    = makeAddr("owner");
    address oracle   = makeAddr("oracle");
    address user1    = makeAddr("user1");
    address user2    = makeAddr("user2");
    address attacker = makeAddr("attacker");

    uint256 constant GOOD_SCORE = 720;
    uint256 constant LOW_SCORE  = 450;
    uint256 constant MAX_SCORE  = 850;
    uint256 constant MIN_SCORE  = 300;

    function setUp() public {
        vm.prank(owner);
        skore = new SkoreSBT(oracle);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DeployedCorrectly() public view {
        assertEq(skore.oracle(), oracle);
        assertEq(skore.owner(), owner);
        assertEq(skore.getTokenCounter(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                         SCORE REQUEST TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RequestScore_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit SkoreSBT.ScoreRequested(user1, block.timestamp);
        vm.prank(user1);
        skore.requestScore();
    }

    /*//////////////////////////////////////////////////////////////
                          SCORE ISSUE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_IssueScore_MintsToken() public {
        vm.prank(oracle);
        skore.issueScore(user1, GOOD_SCORE, 150, 24, true, 2);

        assertTrue(skore.hasScore(user1));
        assertEq(skore.getTokenCounter(), 1);

        SkoreSBT.ScoreData memory data = skore.getScore(user1);
        assertEq(data.score, GOOD_SCORE);
        assertEq(data.totalTransactions, 150);
        assertEq(data.walletAgeMonths, 24);
        assertTrue(data.hasDefiHistory);
        assertEq(data.chainCount, 2);
    }

    function test_IssueScore_EmitsScoreIssued() public {
        vm.expectEmit(true, true, false, true);
        emit SkoreSBT.ScoreIssued(user1, 0, GOOD_SCORE, block.timestamp);

        vm.prank(oracle);
        skore.issueScore(user1, GOOD_SCORE, 150, 24, true, 2);
    }

    function test_UpdateScore_EmitsScoreUpdated() public {
        vm.prank(oracle);
        skore.issueScore(user1, GOOD_SCORE, 150, 24, true, 2);

        vm.expectEmit(true, true, false, true);
        emit SkoreSBT.ScoreUpdated(user1, 0, GOOD_SCORE, 800, block.timestamp);

        vm.prank(oracle);
        skore.issueScore(user1, 800, 200, 26, true, 3);

        SkoreSBT.ScoreData memory data = skore.getScore(user1);
        assertEq(data.score, 800);
        assertEq(data.chainCount, 3);
    }

    function test_MultipleUsers_GetDifferentTokenIds() public {
        vm.prank(oracle);
        skore.issueScore(user1, GOOD_SCORE, 100, 12, false, 1);

        vm.prank(oracle);
        skore.issueScore(user2, LOW_SCORE, 20, 3, false, 1);

        assertEq(skore.getTokenCounter(), 2);
        assertTrue(skore.hasScore(user1));
        assertTrue(skore.hasScore(user2));
    }

    /*//////////////////////////////////////////////////////////////
                          SCORE LABEL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ScoreLabel_Excellent() public {
        vm.prank(oracle);
        skore.issueScore(user1, 750, 100, 12, true, 2);
        assertEq(skore.getScoreLabel(user1), "Excellent");
    }

    function test_ScoreLabel_Good() public {
        vm.prank(oracle);
        skore.issueScore(user1, 670, 80, 10, true, 1);
        assertEq(skore.getScoreLabel(user1), "Good");
    }

    function test_ScoreLabel_Fair() public {
        vm.prank(oracle);
        skore.issueScore(user1, 580, 50, 6, false, 1);
        assertEq(skore.getScoreLabel(user1), "Fair");
    }

    function test_ScoreLabel_Poor() public {
        vm.prank(oracle);
        skore.issueScore(user1, 500, 20, 3, false, 1);
        assertEq(skore.getScoreLabel(user1), "Poor");
    }

    function test_ScoreLabel_VeryPoor() public {
        vm.prank(oracle);
        skore.issueScore(user1, MIN_SCORE, 5, 1, false, 1);
        assertEq(skore.getScoreLabel(user1), "Very Poor");
    }

    /*//////////////////////////////////////////////////////////////
                          SOULBOUND TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Revert_TransferBlocked() public {
        vm.prank(oracle);
        skore.issueScore(user1, GOOD_SCORE, 100, 12, true, 2);

        vm.prank(user1);
        vm.expectRevert(SkoreSBT.SkoreSBT__Soulbound.selector);
        skore.transferFrom(user1, user2, 0);
    }

    function test_Revert_ApproveBlocked() public {
        vm.prank(oracle);
        skore.issueScore(user1, GOOD_SCORE, 100, 12, true, 2);

        vm.prank(user1);
        vm.expectRevert(SkoreSBT.SkoreSBT__Soulbound.selector);
        skore.approve(user2, 0);
    }

    function test_Revert_SetApprovalForAllBlocked() public {
        vm.prank(user1);
        vm.expectRevert(SkoreSBT.SkoreSBT__Soulbound.selector);
        skore.setApprovalForAll(user2, true);
    }

    /*//////////////////////////////////////////////////////////////
                           ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Revert_OnlyOracleCanIssueScore() public {
        vm.prank(attacker);
        vm.expectRevert(SkoreSBT.SkoreSBT__NotOracle.selector);
        skore.issueScore(user1, GOOD_SCORE, 100, 12, true, 2);
    }

    function test_Revert_InvalidScoreTooHigh() public {
        vm.prank(oracle);
        vm.expectRevert(SkoreSBT.SkoreSBT__InvalidScore.selector);
        skore.issueScore(user1, 851, 100, 12, true, 2);
    }

    function test_Revert_InvalidScoreTooLow() public {
        vm.prank(oracle);
        vm.expectRevert(SkoreSBT.SkoreSBT__InvalidScore.selector);
        skore.issueScore(user1, 299, 100, 12, true, 2);
    }

    function test_Revert_ZeroAddressScore() public {
        vm.prank(oracle);
        vm.expectRevert(SkoreSBT.SkoreSBT__ZeroAddress.selector);
        skore.issueScore(address(0), GOOD_SCORE, 100, 12, true, 2);
    }

    function test_Revert_GetScoreNoToken() public {
        vm.expectRevert(SkoreSBT.SkoreSBT__NoScoreFound.selector);
        skore.getScore(user1);
    }

    function test_Revert_GetLabelNoToken() public {
        vm.expectRevert(SkoreSBT.SkoreSBT__NoScoreFound.selector);
        skore.getScoreLabel(user1);
    }

    function test_OnlyOwnerCanSetOracle() public {
        vm.prank(attacker);
        vm.expectRevert();
        skore.setOracle(attacker);
    }

    function test_OwnerCanUpdateOracle() public {
        address newOracle = makeAddr("newOracle");
        vm.prank(owner);
        skore.setOracle(newOracle);
        assertEq(skore.oracle(), newOracle);
    }

    /*//////////////////////////////////////////////////////////////
                             FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_IssueScore(
        uint256 score,
        uint256 totalTx,
        uint256 ageMonths,
        bool hasDefi,
        uint8 chainCount
    ) public {
        score = bound(score, MIN_SCORE, MAX_SCORE);
        totalTx = bound(totalTx, 0, 100_000);
        ageMonths = bound(ageMonths, 0, 120);

        vm.prank(oracle);
        skore.issueScore(user1, score, totalTx, ageMonths, hasDefi, chainCount);

        SkoreSBT.ScoreData memory data = skore.getScore(user1);
        assertEq(data.score, score);
        assertTrue(skore.hasScore(user1));
    }
}