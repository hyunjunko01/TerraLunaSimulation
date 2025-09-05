// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Terra} from "./Terra.sol";
import {Luna} from "./Luna.sol";
import {AnchorUST} from "./AnchorUST.sol";
import {BondedLUNA} from "./BondedLUNA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AnchorProtocol is ReentrancyGuard {
    error AnchorProtocol__NeedsMoreThanZero();
    error AnchorProtocol__TransferFailed();
    error AnchorProtocol__InsufficientBalance();
    error AnchorProtocol__NotEnoughTimeToUnstake();
    error AnchorProtocol__NothingToWithdraw();

    uint256 public constant ANCHOR_INTEREST_RATE = 20; // 20% APY
    uint256 public constant LUNA_STAKING_REWARD_RATE = 10; // 10% APY
    uint256 public constant LUNA_STAKING_PERIOD = 7 days;
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    uint256 public constant PRECISION = 1e18;

    uint256 public s_lunaTotalStaked;
    uint256 public s_bLunaTotalSupply;
    uint256 public s_lunaExchangeRate; // LUNA to bLUNA exchange rate

    // User deposit information
    struct DepositInfo {
        uint256 exchangeRate;
        uint256 aUSTBalance;
        uint256 lastUpdateTime; // 마지막 이자 계산 시점
        uint256 accruedInterest; // 누적된 미지급 이자
    }

    struct StakeInfo {
        uint256 lunaStaked;
        uint256 bLunaAmount;
        uint256 unstakeTime;
        uint256 lunaToWithdraw;
    }

    mapping(address user => DepositInfo) private s_depositInfo;
    mapping(address user => StakeInfo) private s_userStakeInfo;

    Terra public immutable i_terra;
    Luna public immutable i_luna;
    AnchorUST public immutable i_aUST;
    BondedLUNA public immutable i_bLUNA;

    event aUSTMinted(address indexed user, uint256 indexed amount);
    event bLUNAMinted(address indexed user, uint256 indexed amount);

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert AnchorProtocol__NeedsMoreThanZero();
        }
        _;
    }

    constructor(address terraAddress, address lunaAddress, address aUSTAddress, address bLUNAAddress) {
        i_terra = Terra(terraAddress);
        i_luna = Luna(lunaAddress);
        i_aUST = AnchorUST(aUSTAddress);
        i_bLUNA = BondedLUNA(bLUNAAddress);
    }

    function depositUST(uint256 depositAmount) public moreThanZero(depositAmount) nonReentrant {
        DepositInfo storage userDeposit = s_depositInfo[msg.sender];

        if (userDeposit.lastUpdateTime == 0) {
            userDeposit.exchangeRate = PRECISION;
            userDeposit.lastUpdateTime = block.timestamp;
        }

        _updateUserInterest(msg.sender);

        bool success = i_terra.transferFrom(msg.sender, address(this), depositAmount);
        if (!success) {
            revert AnchorProtocol__TransferFailed();
        }

        i_aUST.mint(msg.sender, depositAmount);
        userDeposit.aUSTBalance += depositAmount;
        emit aUSTMinted(msg.sender, depositAmount);
    }

    function withdrawUST(uint256 aUSTAmount) public moreThanZero(aUSTAmount) nonReentrant {
        DepositInfo storage userDeposit = s_depositInfo[msg.sender];

        _updateUserInterest(msg.sender);

        if (aUSTAmount > userDeposit.aUSTBalance) {
            revert AnchorProtocol__InsufficientBalance();
        }

        uint256 ustToReturn = (aUSTAmount * userDeposit.exchangeRate) / PRECISION;

        i_aUST.burn(msg.sender, aUSTAmount);
        userDeposit.aUSTBalance -= aUSTAmount;

        bool success = i_terra.transfer(msg.sender, ustToReturn);
        if (!success) {
            revert AnchorProtocol__TransferFailed();
        }
    }

    function stakeLUNA(uint256 stakeAmount) public moreThanZero(stakeAmount) nonReentrant {
        StakeInfo storage userStakeInfo = s_userStakeInfo[msg.sender];

        _updateLunaExchangeRate();

        bool success = i_luna.transferFrom(msg.sender, address(this), stakeAmount);
        if (!success) {
            revert AnchorProtocol__TransferFailed();
        }
        userStakeInfo.lunaStaked += stakeAmount;
        s_lunaTotalStaked += stakeAmount;
        uint256 bLUNAtoMint = (stakeAmount * PRECISION) / s_lunaExchangeRate;

        i_bLUNA.mint(msg.sender, bLUNAtoMint);
        userStakeInfo.bLunaAmount += bLUNAtoMint;
        s_bLunaTotalSupply += bLUNAtoMint;
        emit bLUNAMinted(msg.sender, bLUNAtoMint);
    }

    function unstakeLUNA(uint256 bLUNAAmount) public moreThanZero(bLUNAAmount) nonReentrant {
        StakeInfo storage userStakeInfo = s_userStakeInfo[msg.sender];
        if (bLUNAAmount > userStakeInfo.bLunaAmount) {
            revert AnchorProtocol__InsufficientBalance();
        }
        i_bLUNA.burn(msg.sender, bLUNAAmount);
        userStakeInfo.bLunaAmount -= bLUNAAmount;
        s_bLunaTotalSupply -= bLUNAAmount;

        _updateLunaExchangeRate();
        userStakeInfo.lunaToWithdraw += (bLUNAAmount * s_lunaExchangeRate) / PRECISION;
        userStakeInfo.unstakeTime = block.timestamp;
    }

    function withdrawLUNA() public nonReentrant {
        StakeInfo storage userStakeInfo = s_userStakeInfo[msg.sender];
        if (block.timestamp < userStakeInfo.unstakeTime + LUNA_STAKING_PERIOD) {
            revert AnchorProtocol__NotEnoughTimeToUnstake();
        }

        uint256 lunaToWithdraw = userStakeInfo.lunaToWithdraw;

        if (lunaToWithdraw == 0) {
            revert AnchorProtocol__NothingToWithdraw();
        }

        bool success = i_luna.transfer(msg.sender, lunaToWithdraw);
        if (!success) {
            revert AnchorProtocol__TransferFailed();
        }

        s_lunaTotalStaked -= lunaToWithdraw;
        userStakeInfo.lunaToWithdraw = 0;
        userStakeInfo.unstakeTime = 0;
    }

    function borrowUST() public {}

    //////////////////////////////////////////////
    // Private & Internal View & Pure Functions //
    //////////////////////////////////////////////

    /// @notice calculate user's interest
    /// this function updates user's interest based on the time elapsed since the last update.
    /// we will use e^x approximation to calculate compound interest.
    /// And then we will use Taylor expansion to approximate e^x.

    function _updateUserInterest(address user) internal {
        DepositInfo storage depositInfo = s_depositInfo[user];

        if (depositInfo.aUSTBalance == 0) {
            return;
        }

        uint256 timeElapsed = block.timestamp - depositInfo.lastUpdateTime;
        if (timeElapsed > 0) {
            uint256 exponent = (PRECISION * ANCHOR_INTEREST_RATE * timeElapsed) / (100 * SECONDS_PER_YEAR);
            uint256 compoundFactor = _calculateCompoundGrowth(exponent);

            depositInfo.exchangeRate = (depositInfo.exchangeRate * compoundFactor) / PRECISION;
            depositInfo.lastUpdateTime = block.timestamp;
        }
    }

    function _updateLunaExchangeRate() internal {
        if (s_bLunaTotalSupply == 0) {
            s_lunaExchangeRate = PRECISION;
        } else {
            s_lunaExchangeRate = (s_lunaTotalStaked * PRECISION) / s_bLunaTotalSupply;
        }
    }

    function _calculateCompoundGrowth(uint256 x) internal pure returns (uint256) {
        // x는 이미 PRECISION으로 스케일된 값
        if (x == 0) return PRECISION;

        uint256 result = PRECISION; // 1
        uint256 term = x; // x

        // 1차항: x
        result += term;

        // 2차항: x²/2!
        term = (term * x) / (PRECISION * 2);
        result += term;

        // 3차항: x³/3!
        term = (term * x) / (PRECISION * 3);
        result += term;

        // 4차항: x⁴/4!
        term = (term * x) / (PRECISION * 4);
        result += term;

        // 5차항: x⁵/5! (충분히 정확함)
        term = (term * x) / (PRECISION * 5);
        result += term;

        return result;
    }
}
