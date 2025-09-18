// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {LUNAStakingSystem} from "../../src/Protocols/AnchorProtocol/LUNAStakingSystem.sol";
import {Luna} from "../../src/Tokens/Luna.sol";
import {BondedLUNA} from "../../src/Tokens/BondedLuna.sol";
import {DeployLUNAStaking} from "../../script/deployment/DeployLUNAStaking.s.sol";

contract LUNAStakingSystemTest is Test {
    LUNAStakingSystem stakingSystem;
    Luna luna;
    BondedLUNA bLuna;
    DeployLUNAStaking deployer;

    address user1;
    address user2;

    uint256 public constant INITIAL_LUNA_BALANCE = 1000 * 1e18;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant STAKING_PERIOD = 7 days;
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 3600;
    uint256 public constant REWARD_RATE = 10; // 10% APY

    function setUp() public {
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy contracts
        deployer = new DeployLUNAStaking();
        (stakingSystem, luna, bLuna) = deployer.run();

        // Mint LUNA to users for testing
        luna.mint(user1, INITIAL_LUNA_BALANCE);
        luna.mint(user2, INITIAL_LUNA_BALANCE);

        // Sanity checks
        assertEq(luna.balanceOf(user1), INITIAL_LUNA_BALANCE);
        assertEq(luna.balanceOf(user2), INITIAL_LUNA_BALANCE);
        assertEq(stakingSystem.getLUNAExchangeRate(), PRECISION); // Initial 1:1 rate
    }

    // ========== Staking Tests ==========

    function testStakeLUNA() public {
        uint256 stakeAmount = 100 * 1e18;

        vm.startPrank(user1);
        luna.approve(address(stakingSystem), stakeAmount);

        uint256 initialLunaBalance = luna.balanceOf(user1);
        uint256 initialBLunaBalance = bLuna.balanceOf(user1);

        stakingSystem.stakeLUNA(stakeAmount);
        vm.stopPrank();

        // Check LUNA transferred
        assertEq(luna.balanceOf(user1), initialLunaBalance - stakeAmount);
        assertEq(luna.balanceOf(address(stakingSystem)), stakeAmount);

        // Check bLUNA minted (1:1 ratio initially)
        uint256 expectedBLuna = stakeAmount; // 1:1 ratio
        assertEq(bLuna.balanceOf(user1), initialBLunaBalance + expectedBLuna);

        // Check staking system state
        assertEq(stakingSystem.s_amountStakedLUNA(), stakeAmount);
    }

    function testStakeMultipleUsers() public {
        uint256 stakeAmount1 = 100 * 1e18;
        uint256 stakeAmount2 = 200 * 1e18;

        // User1 stakes
        vm.startPrank(user1);
        luna.approve(address(stakingSystem), stakeAmount1);
        stakingSystem.stakeLUNA(stakeAmount1);
        vm.stopPrank();

        // User2 stakes
        vm.startPrank(user2);
        luna.approve(address(stakingSystem), stakeAmount2);
        stakingSystem.stakeLUNA(stakeAmount2);
        vm.stopPrank();

        // Check total staked amount
        assertEq(stakingSystem.s_amountStakedLUNA(), stakeAmount1 + stakeAmount2);

        // Check individual bLUNA balances
        assertEq(bLuna.balanceOf(user1), stakeAmount1);
        assertEq(bLuna.balanceOf(user2), stakeAmount2);
    }

    function testStakeZeroAmount() public {
        vm.startPrank(user1);
        luna.approve(address(stakingSystem), 0);

        vm.expectRevert(LUNAStakingSystem.LUNAStakingSystem__NeedsMoreThanZero.selector);
        stakingSystem.stakeLUNA(0);
        vm.stopPrank();
    }

    // ========== Exchange Rate Tests ==========

    function testExchangeRateAfterRewards() public {
        uint256 stakeAmount = 100 * 1e18;

        // Stake LUNA
        vm.startPrank(user1);
        luna.approve(address(stakingSystem), stakeAmount);
        stakingSystem.stakeLUNA(stakeAmount);
        vm.stopPrank();

        // Initial exchange rate should be 1:1
        assertEq(stakingSystem.getLUNAExchangeRate(), PRECISION);

        // Fast forward 1 year
        vm.warp(block.timestamp + SECONDS_PER_YEAR);

        // Trigger exchange rate update by staking again
        vm.startPrank(user2);
        luna.approve(address(stakingSystem), 1 * 1e18);
        stakingSystem.stakeLUNA(1 * 1e18);
        vm.stopPrank();

        // Exchange rate should have increased due to rewards
        uint256 newExchangeRate = stakingSystem.getLUNAExchangeRate();
        console.log("Exchange rate after 1 year:", newExchangeRate);

        // Should be approximately 1.1 (10% increase)
        uint256 expectedRate = PRECISION + (PRECISION * REWARD_RATE) / 100;
        assertApproxEqRel(newExchangeRate, expectedRate, 0.01e18); // 1% tolerance
    }

    function testExchangeRateWithMultipleUpdates() public {
        uint256 stakeAmount = 100 * 1e18;

        vm.startPrank(user1);
        luna.approve(address(stakingSystem), stakeAmount);
        stakingSystem.stakeLUNA(stakeAmount);
        vm.stopPrank();

        // Fast forward 6 months
        vm.warp(block.timestamp + SECONDS_PER_YEAR / 2);

        // Trigger first update
        vm.startPrank(user2);
        luna.approve(address(stakingSystem), 1 * 1e18);
        stakingSystem.stakeLUNA(1 * 1e18);

        uint256 exchangeRateAfter6Months = stakingSystem.getLUNAExchangeRate();
        console.log("Exchange rate after 6 months:", exchangeRateAfter6Months);

        // Fast forward another 6 months
        vm.warp(block.timestamp + SECONDS_PER_YEAR / 2);

        // Trigger second update
        luna.approve(address(stakingSystem), 1 * 1e18);
        stakingSystem.stakeLUNA(1 * 1e18);
        vm.stopPrank();

        uint256 finalExchangeRate = stakingSystem.getLUNAExchangeRate();
        console.log("Final exchange rate after 1 year:", finalExchangeRate);

        // Should be higher than 6 months rate
        assertGt(finalExchangeRate, exchangeRateAfter6Months);
    }

    // ========== Unstaking Tests ==========

    function testUnstakeLUNA() public {
        uint256 stakeAmount = 100 * 1e18;

        // First stake
        vm.startPrank(user1);
        luna.approve(address(stakingSystem), stakeAmount);
        stakingSystem.stakeLUNA(stakeAmount);

        uint256 bLunaBalance = bLuna.balanceOf(user1);
        uint256 unstakeAmount = bLunaBalance / 2; // Unstake half

        // Unstake
        stakingSystem.unstakeLUNA(unstakeAmount);
        vm.stopPrank();

        // Check bLUNA burned
        assertEq(bLuna.balanceOf(user1), bLunaBalance - unstakeAmount);

        // Check unstake request created (but LUNA not yet withdrawn)
        assertEq(luna.balanceOf(user1), INITIAL_LUNA_BALANCE - stakeAmount);
    }

    function testUnstakeInsufficientBalance() public {
        uint256 stakeAmount = 100 * 1e18;

        vm.startPrank(user1);
        luna.approve(address(stakingSystem), stakeAmount);
        stakingSystem.stakeLUNA(stakeAmount);

        uint256 bLunaBalance = bLuna.balanceOf(user1);

        vm.expectRevert(LUNAStakingSystem.LUNAStakingSystem__InsufficientBalance.selector);
        stakingSystem.unstakeLUNA(bLunaBalance + 1); // More than balance
        vm.stopPrank();
    }

    // ========== Withdrawal Tests ==========

    function testWithdrawAfterUnlockPeriod() public {
        uint256 stakeAmount = 100 * 1e18;

        // Stake and unstake
        vm.startPrank(user1);
        luna.approve(address(stakingSystem), stakeAmount);
        stakingSystem.stakeLUNA(stakeAmount);

        uint256 bLunaBalance = bLuna.balanceOf(user1);
        stakingSystem.unstakeLUNA(bLunaBalance);

        // Try to withdraw immediately (should fail)
        vm.expectRevert(LUNAStakingSystem.LUNAStakingSystem__NothingToWithdraw.selector);
        stakingSystem.withdrawLUNA();

        // Fast forward past unlock period
        vm.warp(block.timestamp + STAKING_PERIOD + 1);

        uint256 lunaBalanceBefore = luna.balanceOf(user1);
        stakingSystem.withdrawLUNA();
        vm.stopPrank();

        // Check LUNA returned
        uint256 lunaBalanceAfter = luna.balanceOf(user1);
        assertEq(lunaBalanceAfter, lunaBalanceBefore + stakeAmount);

        // Check staking system state updated
        assertEq(stakingSystem.s_amountStakedLUNA(), 0);
    }

    function testWithdrawMultipleRequests() public {
        uint256 stakeAmount = 200 * 1e18;

        vm.startPrank(user1);
        luna.approve(address(stakingSystem), stakeAmount);
        stakingSystem.stakeLUNA(stakeAmount);

        uint256 bLunaBalance = bLuna.balanceOf(user1);

        // Create first unstake request
        stakingSystem.unstakeLUNA(bLunaBalance / 2);

        // Fast forward 3 days and create second request
        vm.warp(block.timestamp + 3 days);
        stakingSystem.unstakeLUNA(bLunaBalance / 2);

        // Fast forward past first unlock period (7 days from start)
        vm.warp(block.timestamp + 4 days + 1); // Total: 7 days + 1 second from start

        uint256 lunaBalanceBefore = luna.balanceOf(user1);
        stakingSystem.withdrawLUNA();

        // Should only withdraw first request
        uint256 expectedWithdrawal = stakeAmount / 2; // First request
        assertEq(luna.balanceOf(user1), lunaBalanceBefore + expectedWithdrawal);

        // Fast forward past second unlock period
        vm.warp(block.timestamp + 3 days + 1); // Past second request unlock

        lunaBalanceBefore = luna.balanceOf(user1);
        stakingSystem.withdrawLUNA();

        // Should withdraw second request
        assertEq(luna.balanceOf(user1), lunaBalanceBefore + expectedWithdrawal);
        vm.stopPrank();
    }

    function testWithdrawWithNoRequests() public {
        vm.startPrank(user1);
        vm.expectRevert(LUNAStakingSystem.LUNAStakingSystem__NothingToWithdraw.selector);
        stakingSystem.withdrawLUNA();
        vm.stopPrank();
    }

    // ========== Integration Tests ==========

    function testFullStakingCycleWithRewards() public {
        uint256 stakeAmount = 100 * 1e18;

        // Stake LUNA
        vm.startPrank(user1);
        luna.approve(address(stakingSystem), stakeAmount);
        stakingSystem.stakeLUNA(stakeAmount);

        uint256 initialBLuna = bLuna.balanceOf(user1);

        // Fast forward 1 year for rewards
        vm.warp(block.timestamp + SECONDS_PER_YEAR);

        // Unstake all bLUNA
        stakingSystem.unstakeLUNA(initialBLuna);

        // Fast forward past unlock period
        vm.warp(block.timestamp + STAKING_PERIOD + 1);

        uint256 lunaBalanceBefore = luna.balanceOf(user1);
        stakingSystem.withdrawLUNA();
        vm.stopPrank();

        uint256 lunaReceived = luna.balanceOf(user1) - lunaBalanceBefore;
        console.log("LUNA staked:", stakeAmount);
        console.log("LUNA received after 1 year:", lunaReceived);

        // Should receive approximately 110 LUNA (100 + 10% rewards)
        uint256 expectedWithRewards = stakeAmount + (stakeAmount * REWARD_RATE) / 100;
        assertApproxEqRel(lunaReceived, expectedWithRewards, 0.01e18); // 1% tolerance
    }

    // ========== View Function Tests ==========

    function testGetExchangeRate() public {
        // Initial rate should be 1:1
        assertEq(stakingSystem.getLUNAExchangeRate(), PRECISION);

        // Rate should remain 1:1 if no staking occurred
        vm.warp(block.timestamp + SECONDS_PER_YEAR);
        assertEq(stakingSystem.getLUNAExchangeRate(), PRECISION);
    }
}
