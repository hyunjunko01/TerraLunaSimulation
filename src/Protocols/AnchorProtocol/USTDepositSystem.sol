// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AnchorUST} from "../../Tokens/AnchorUST.sol";

/// @title UST Deposit System - Simplified UST Deposit System with aUST
/// @notice Users deposit UST, receive aUST which appreciates in value via exchange rate accrual.
/// @author HyunJun Ko
contract USTDepositSystem is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------- Errors ----------------
    error AnchorProtocol__NeedsMoreThanZero();
    error AnchorProtocol__InsufficientBalance();

    // ---------------- Constants ----------------
    uint256 public constant PRECISION = 1e18;
    uint256 public constant ANNUAL_INTEREST_RATE = 20; // 20% APR
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 3600;

    // ---------------- State ----------------
    uint256 public s_depositedUST;
    uint256 public s_ustExchangeRate; // scaled by 1e18
    uint256 public s_lastUpdateTime;

    IERC20 public immutable i_UST;
    AnchorUST public immutable i_aUST;

    // ---------------- Events ----------------
    event Deposit(address indexed user, uint256 ustAmount, uint256 aUSTMinted);
    event Withdraw(address indexed user, uint256 ustAmount, uint256 aUSTBurned);

    // ---------------- Modifiers ----------------
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert AnchorProtocol__NeedsMoreThanZero();
        }
        _;
    }

    // ---------------- Constructor ----------------
    constructor(address ustAddress, address aUSTAddress) {
        i_UST = IERC20(ustAddress);
        i_aUST = AnchorUST(aUSTAddress);

        s_ustExchangeRate = PRECISION; // initial: 1 aUST = 1 UST
        s_lastUpdateTime = block.timestamp;
    }

    // ---------------- External User Functions ----------------
    function depositUST(uint256 ustAmount) external moreThanZero(ustAmount) nonReentrant {
        _updateExchangeRate();

        // Transfer UST into protocol
        i_UST.safeTransferFrom(msg.sender, address(this), ustAmount);
        s_depositedUST += ustAmount;

        // Mint aUST to user
        uint256 aUSTToMint = (ustAmount * PRECISION) / s_ustExchangeRate;
        i_aUST.mint(msg.sender, aUSTToMint);

        emit Deposit(msg.sender, ustAmount, aUSTToMint);
    }

    function withdrawUST(uint256 aUSTAmount) external moreThanZero(aUSTAmount) nonReentrant {
        _updateExchangeRate();

        if (aUSTAmount > i_aUST.balanceOf(msg.sender)) {
            revert AnchorProtocol__InsufficientBalance();
        }

        // Calculate how much UST to return
        uint256 ustToReturn = (aUSTAmount * s_ustExchangeRate) / PRECISION;

        // Burn aUST and send UST
        i_aUST.burn(msg.sender, aUSTAmount);
        i_UST.safeTransfer(msg.sender, ustToReturn);

        s_depositedUST -= ustToReturn;

        emit Withdraw(msg.sender, ustToReturn, aUSTAmount);
    }

    // ---------------- Internal Logic ----------------
    function _updateExchangeRate() internal {
        uint256 aUSTTotalSupply = i_aUST.totalSupply();

        if (aUSTTotalSupply == 0) {
            s_lastUpdateTime = block.timestamp;
            return;
        }

        uint256 nowTime = block.timestamp;
        uint256 dt = nowTime - s_lastUpdateTime;
        if (dt == 0) return;

        // Linear interest approximation: exchangeRate *= (1 + r*dt/year)
        uint256 factor = PRECISION + (ANNUAL_INTEREST_RATE * PRECISION * dt) / (100 * SECONDS_PER_YEAR);

        s_ustExchangeRate = (s_depositedUST * factor) / aUSTTotalSupply;
        s_lastUpdateTime = nowTime;
    }

    // ---------------- View Helpers ----------------
}
