// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LUNAStakingSystem} from "./LUNAStakingSystem.sol";

contract USTLoanSystem is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------- Errors ----------------
    error USTLoanSystem__NeedsMoreThanZero();
    error USTLoanSystem__InsufficientBalance();
    error USTLoanSystem__LTVIsBroken();
    error USTLoanSystem__TooMuchUST();
    error USTLoanSystem__TooMuchCollateral();

    // ---------------- Constants ----------------
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_LOAN_TO_VALUE = 7e17; // max LTV = 70%
    uint256 public constant ANNUAL_INTEREST_RATE = 10;
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 3600;

    // ---------------- State ----------------

    struct UserInfo {
        uint256 collateralAmount;
        uint256 loanAmount;
        uint256 lastUpdateTime;
    }

    mapping(address => UserInfo) public s_userInfo;

    IERC20 public immutable i_UST;
    IERC20 public immutable i_bLUNA;

    LUNAStakingSystem public immutable i_LUNAStaking;

    // ---------------- Events ----------------
    event CollateralDeposited(address indexed user, uint256 bLUNAAmount);
    event USTBorrowed(address indexed user, uint256 ustAmount);
    event USTRedeemed(address indexed user, uint256 ustAmount);
    event CollateralGetBack(address indexed user, uint256 bLUNAAmount);

    // ---------------- Modifiers ----------------
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert USTLoanSystem__NeedsMoreThanZero();
        }
        _;
    }

    // ---------------- Constructor ----------------
    constructor(address ustAddress, address bLUNAAddress, address LUNAStakingSystemAddress) {
        i_UST = IERC20(ustAddress);
        i_bLUNA = IERC20(bLUNAAddress);
        i_LUNAStaking = LUNAStakingSystem(LUNAStakingSystemAddress);
    }

    // ---------------- External User Functions ----------------

    // 가스비 절약을 위해 로직을 한번에 처리하는 함수 구현
    function depositCollateralAndBorrowUST(uint256 bLUNAAmount, uint256 ustAmount) external {
        depositCollateral(bLUNAAmount);
        borrowUST(ustAmount);
    }

    function depositCollateral(uint256 bLUNAAmount) public moreThanZero(bLUNAAmount) nonReentrant {
        i_bLUNA.safeTransferFrom(msg.sender, address(this), bLUNAAmount);
        s_userInfo[msg.sender].collateralAmount += bLUNAAmount;

        emit CollateralDeposited(msg.sender, bLUNAAmount);
    }

    function borrowUST(uint256 ustAmount) public moreThanZero(ustAmount) nonReentrant {
        _updateLoanAmount(msg.sender);
        s_userInfo[msg.sender].loanAmount += ustAmount;
        _revertIfLTVIsBroken(s_userInfo[msg.sender].loanAmount, s_userInfo[msg.sender].collateralAmount);

        i_UST.safeTransfer(msg.sender, ustAmount);
        s_userInfo[msg.sender].lastUpdateTime = block.timestamp;
        emit USTBorrowed(msg.sender, ustAmount);
    }

    function redeemCollateral(uint256 ustAmount, uint256 bLUNAAmount) external nonReentrant {
        _updateLoanAmount(msg.sender);
        _redeemUST(ustAmount);
        _getBackCollateral(bLUNAAmount);
    }

    function liquidate(address user) external {
        _updateLoanAmount(user);
        uint256 loanAmount = s_userInfo[user].loanAmount;
        uint256 collateralValue = s_userInfo[user].collateralAmount * i_LUNAStaking.getLUNAExchangeRate();

        if (collateralValue == 0) revert USTLoanSystem__InsufficientBalance();

        uint256 userLTV = (loanAmount * PRECISION) / collateralValue;

        if (userLTV > MAX_LOAN_TO_VALUE) {
            s_userInfo[user].collateralAmount = 0;
            s_userInfo[user].loanAmount = 0;
        } // 만약 user의 LTV가 최대 범위를 초과했다면 user의 collateralAmount와 loanAmount를 둘 다 없애서 청산시킨다.
            // 프로토콜 입장에서 user의 LTV를 적절하게 관찰하는 경우 collateral의 value가 loan의 value보다 커지는 일은 없기 때문에 대출 시스템의 안정성을 유지할 수 있다.
    }

    // ---------------- Internal Logic ----------------
    function _redeemUST(uint256 ustAmount) private moreThanZero(ustAmount) {
        if (s_userInfo[msg.sender].loanAmount < ustAmount) {
            revert USTLoanSystem__TooMuchUST();
        }
        i_UST.safeTransferFrom(msg.sender, address(this), ustAmount);
        s_userInfo[msg.sender].loanAmount -= ustAmount;

        emit USTRedeemed(msg.sender, ustAmount);
    }

    function _getBackCollateral(uint256 bLUNAAmount) private moreThanZero(bLUNAAmount) {
        if (s_userInfo[msg.sender].collateralAmount < bLUNAAmount) {
            revert USTLoanSystem__TooMuchCollateral();
        }
        s_userInfo[msg.sender].collateralAmount -= bLUNAAmount;
        _revertIfLTVIsBroken(s_userInfo[msg.sender].loanAmount, s_userInfo[msg.sender].collateralAmount);

        i_bLUNA.safeTransfer(msg.sender, bLUNAAmount);
        emit CollateralGetBack(msg.sender, bLUNAAmount);
    }

    function _revertIfLTVIsBroken(uint256 loanAmount, uint256 collateralAmount) internal view {
        if (loanAmount == 0) return;

        uint256 collateralValue = collateralAmount * i_LUNAStaking.getLUNAExchangeRate();
        if (collateralValue == 0) revert USTLoanSystem__InsufficientBalance();

        uint256 userLTV = (loanAmount * PRECISION) / collateralValue;
        if (userLTV > MAX_LOAN_TO_VALUE) revert USTLoanSystem__LTVIsBroken();
    }

    function _updateLoanAmount(address user) internal {
        UserInfo storage userInfo = s_userInfo[user];

        if (userInfo.loanAmount == 0) {
            return;
        }

        uint256 nowTime = block.timestamp;
        uint256 dt = nowTime - userInfo.lastUpdateTime;
        if (dt == 0) return;

        uint256 factor = PRECISION + (ANNUAL_INTEREST_RATE * PRECISION * dt) / (100 * SECONDS_PER_YEAR);
        userInfo.loanAmount = (userInfo.loanAmount * factor) / PRECISION;
        userInfo.lastUpdateTime = block.timestamp;
    }
}
