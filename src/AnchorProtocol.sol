// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Terra} from "./Terra.sol";
import {Luna} from "./Luna.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AnchorProtocol is ReentrancyGuard {
    error AnchorProtocol__NeedsMoreThanZero();
    error AnchorProtocol__TransferFailed();

    uint256 public constant ANCHOR_INTEREST_RATE = 20; // 20% APY
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;

    // User deposit information
    struct DepositInfo {
        uint256 principalAmount; // 원금
        uint256 lastUpdateTime; // 마지막 이자 계산 시점
        uint256 accruedInterest; // 누적된 미지급 이자
    }

    mapping(address user => DepositInfo) private s_userDeposits;
    mapping(address user => uint256 amountUSTDeposited) private s_USTDeposited;

    Terra public immutable i_terra;
    Luna public immutable i_luna;

    event USTDeposited(address indexed user, uint256 indexed amount);

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert AnchorProtocol__NeedsMoreThanZero();
        }
        _;
    }

    constructor(address terraAddress, address lunaAddress) {
        i_terra = Terra(terraAddress);
        i_luna = Luna(lunaAddress);
    }

    function depositUST(uint256 depositAmount) public moreThanZero(depositAmount) nonReentrant {
        s_USTDeposited[msg.sender] += depositAmount;
        emit USTDeposited(msg.sender, depositAmount);
        bool success = i_terra.transferFrom(msg.sender, address(this), depositAmount);
        if (!success) {
            revert AnchorProtocol__TransferFailed();
        }
    }

    function withdrawUST(uint256 withdrawAmount) public moreThanZero(withdrawAmount) nonReentrant {}

    function stakeLUNA(uint256 stakeAmount) public {}
    function borrowUST() public {}

    //////////////////////////////////////////////
    // Private & Internal View & Pure Functions //
    //////////////////////////////////////////////

    function _updateUserInterest(address user) internal {
        DepositInfo storage deposit = s_userDeposits[user];

        if (deposit.principalAmount == 0) {
            return;
        }

        uint256 timeElapsed = block.timestamp - deposit.lastUpdateTime;
        if (timeElapsed > 0) {
            uint256 interestEarned =
                (deposit.principalAmount * ANCHOR_INTEREST_RATE * timeElapsed) / (100 * SECONDS_PER_YEAR);

            deposit.accruedInterest += interestEarned;
            deposit.lastUpdateTime = block.timestamp;
        }
    }
}
