// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {BondedLUNA} from "../BondedLuna.sol";

/// @title LUNA Staking System - Simplified LUNA Staking System with bLUNA
/// @notice Users stake LUNA, receive bLUNA which represents their staked LUNA and earns staking rewards.
/// @author HyunJun Ko

contract LUNAStakingSystem is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------- Errors ----------------
    error LUNAStakingSystem__NeedsMoreThanZero();
    error LUNAStakingSystem__InsufficientBalance();
    error LUNAStakingSystem__NothingToWithdraw();

    // ---------------- Constants ----------------
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LUNA_STAKING_REWARD_RATE = 10; // 10% APY
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 3600;
    uint256 public constant LUNA_STAKING_PERIOD = 7 days;

    // ---------------- State ----------------
    uint256 public s_amountStakedLUNA;
    uint256 public s_lunaExchangeRate; // scaled by 1e18
    uint256 public s_lastUpdateTime;

    struct UnstakeRequest {
        uint256 lunaAmount;
        uint256 unlockTime;
    }

    mapping(address user => UnstakeRequest[]) public s_unstakeRequests;

    IERC20 public immutable i_LUNA;
    BondedLUNA public immutable i_bLUNA;

    // ---------------- Events ----------------
    event Stake(address indexed user, uint256 lunaAmount, uint256 bLUNAMinted);
    event Unstake(address indexed user, uint256 lunaAmount, uint256 bLUNABurned);
    event Withdraw(address indexed user, uint256 lunaAmount);

    // ---------------- Modifiers ----------------
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert LUNAStakingSystem__NeedsMoreThanZero();
        }
        _;
    }

    // ---------------- Constructor ----------------
    constructor(address lunaAddress, address bLUNAAddress) {
        i_LUNA = IERC20(lunaAddress);
        i_bLUNA = BondedLUNA(bLUNAAddress);

        s_lunaExchangeRate = PRECISION; // initial: 1 bLUNA = 1 LUNA
        s_lastUpdateTime = block.timestamp;
    }

    // ---------------- External User Functions ----------------
    function stakeLUNA(uint256 lunaAmount) external moreThanZero(lunaAmount) nonReentrant {
        _updateExchangeRate();

        // Transfer LUNA into protocol
        i_LUNA.safeTransferFrom(msg.sender, address(this), lunaAmount);

        // Mint bLUNA to user
        uint256 bLUNAToMint = (lunaAmount * PRECISION) / s_lunaExchangeRate;
        i_bLUNA.mint(msg.sender, bLUNAToMint);
        s_amountStakedLUNA += lunaAmount;

        emit Stake(msg.sender, lunaAmount, bLUNAToMint);
    }

    function unstakeLUNA(uint256 bLUNAAmount) external moreThanZero(bLUNAAmount) nonReentrant {
        _updateExchangeRate();

        if (bLUNAAmount > i_bLUNA.balanceOf(msg.sender)) {
            revert LUNAStakingSystem__InsufficientBalance();
        }

        uint256 lunaToUnstake = (bLUNAAmount * s_lunaExchangeRate) / PRECISION;

        // Burn bLUNA from user and transfer LUNA back to user
        i_bLUNA.burn(msg.sender, bLUNAAmount);

        s_unstakeRequests[msg.sender].push(
            UnstakeRequest({lunaAmount: lunaToUnstake, unlockTime: block.timestamp + LUNA_STAKING_PERIOD})
        );

        emit Unstake(msg.sender, lunaToUnstake, bLUNAAmount);
    }

    function withdrawLUNA() external nonReentrant {
        UnstakeRequest[] storage requests = s_unstakeRequests[msg.sender];
        uint256 lunaToWithdraw = 0;

        uint256 i = 0;
        while (i < requests.length) {
            if (block.timestamp >= requests[i].unlockTime) {
                lunaToWithdraw += requests[i].lunaAmount;
                requests[i] = requests[requests.length - 1];
                requests.pop();
            } else {
                i++;
            }
        }

        if (lunaToWithdraw == 0) {
            revert LUNAStakingSystem__NothingToWithdraw();
        }

        i_LUNA.safeTransfer(msg.sender, lunaToWithdraw);
        s_amountStakedLUNA -= lunaToWithdraw;

        emit Withdraw(msg.sender, lunaToWithdraw);
    }

    // ---------------- Internal Logic ----------------

    function _updateExchangeRate() internal {
        uint256 bLUNATotalSupply = i_bLUNA.totalSupply();

        if (bLUNATotalSupply == 0) {
            s_lastUpdateTime = block.timestamp;
            return;
        }

        uint256 nowTime = block.timestamp;
        uint256 dt = nowTime - s_lastUpdateTime;
        if (dt == 0) return;

        // Linear interest approximation: exchangeRate *= (1 + r*dt/year)
        uint256 factor = PRECISION + (LUNA_STAKING_REWARD_RATE * PRECISION * dt) / (100 * SECONDS_PER_YEAR);

        s_lunaExchangeRate = (s_amountStakedLUNA * factor) / bLUNATotalSupply;
        s_lastUpdateTime = nowTime;
    }

    // ---------------- External View Functions ----------------
    function getLUNAExchangeRate() external view returns (uint256) {
        return s_lunaExchangeRate;
    }
}
