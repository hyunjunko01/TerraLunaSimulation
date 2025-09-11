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
    error USTLoanSystem__BreaksHealthFactor();

    // ---------------- Constants ----------------
    uint256 public constant PRECISION = 1e18;
    // ---------------- State ----------------

    struct UserInfo {
        uint256 collateralAmount;
        uint256 loanAmount;
    }

    mapping(address user => UserInfo) public s_userInfo;

    IERC20 public immutable i_UST;
    IERC20 public immutable i_bLUNA;

    LUNAStakingSystem public immutable i_LUNAStaking;

    // ---------------- Events ----------------
    event CollateralDeposited(address indexed user, uint256 bLUNAAmount);
    event CollateralRedeemed(address indexed user, uint256 bLUNAAmount);
    event USTIsTransfered(address indexed user, uint256 ustAmount);

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
    function depositCollateralAndTransferUST(uint256 bLUNAAmount, uint256 ustAmount) external {
        depositCollateral(bLUNAAmount);
        transferUST(ustAmount);
    }

    function depositCollateral(uint256 bLUNAAmount) public moreThanZero(bLUNAAmount) nonReentrant {
        s_userInfo[msg.sender].collateralAmount += bLUNAAmount;
        i_bLUNA.safeTransferFrom(msg.sender, address(this), bLUNAAmount);

        emit CollateralDeposited(msg.sender, bLUNAAmount);
    }

    function borrowUST(uint256 ustAmount) public moreThanZero(ustAmount) nonReentrant {
        s_userInfo[msg.sender].loanAmount += ustAmount;
        _revertIfHealthFactorIsBroken(); // 유저의 loanAmount를 증가시킨 후 healthFactor 계산을 해야 이 함수의 호출로 인한 대출이 문제가 있는지 없는지 확인할 수 있다.
        // 위의 함수에서 revert가 되면 같은 함수에서 이전에 수행된 사항들은 전부 리셋된다.

        i_UST.safeTransfer(msg.sender, ustAmount);
        emit USTIsTransfered(msg.sender, ustAmount);
    }

    function redeemCollateral(uint256 bLUNAAmount) external {}

    function liquidate() external {}

    // ---------------- Internal Logic ----------------

    function _redeemCollateral(uint256 bLUNAAmount) private {
        i_bLUNA.safeTransfer(msg.sender, bLUNAAmount);
        s_userInfo[msg.sender].collateralAmount -= bLUNAAmount;
        emit CollateralRedeemed(msg.sender, bLUNAAmount);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalLoanedUST, uint256 collateralVaule) = _getAccountInformation(user);
        return (totalLoanedUST * PRECISION / collateralValue);
    }

    function _revertIfHealthFactorIsBroken() internal view {
        uint256 userHealthFactor = _healthFactor(msg.sender);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert USTLoanSystem__BreaksHealthFactor();
        }
    }

    function _getAccountInformation(address user) private returns (uint256 totalLoanedUST, uint256 collateralValue) {
        totalLoanedUST = s_userInfo[user].loanAmount;
        collateralValue = s_userInfo[user].collateralAmount * LUNAStaking.getLUNAExchangeRate();

        return (totalLoanedUST, collateralValue);
    }
}
