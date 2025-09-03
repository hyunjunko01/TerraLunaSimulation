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
    error AnchorProtocol__aUSTMintFailed();

    uint256 public constant ANCHOR_INTEREST_RATE = 20; // 20% APY
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    uint256 public constant PRECISION = 1e18;

    // User deposit information
    struct DepositInfo {
        uint256 DepositedUST; // 원금
        uint256 aUSTValue;
        uint256 lastUpdateTime; // 마지막 이자 계산 시점
        uint256 accruedInterest; // 누적된 미지급 이자
    }

    mapping(address user => DepositInfo) private s_depositInfo;

    Terra public immutable i_terra;
    Luna public immutable i_luna;
    AnchorUST public immutable i_aUST;
    BondedLUNA public immutable i_bLUNA;

    event USTDeposited(address indexed user, uint256 indexed amount);
    event aUSTMinted(address indexed user, uint256 indexed amount);

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
        bool success = i_terra.transferFrom(msg.sender, address(this), depositAmount);
        if (!success) {
            revert AnchorProtocol__TransferFailed();
        }
        s_depositInfo[msg.sender].DepositedUST += depositAmount;
        emit USTDeposited(msg.sender, depositAmount);

        bool minted = i_aUST.mint(msg.sender, depositAmount);
        if (!minted) {
            revert AnchorProtocol__aUSTMintFailed();
        }
        emit aUSTMinted(msg.sender, depositAmount);
    }

    function withdrawUST(uint256 aUSTAmount) public moreThanZero(aUSTAmount) nonReentrant {
        _updateUserInterest(msg.sender);
    }

    function stakeLUNA(uint256 stakeAmount) public {}
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

        if (depositInfo.DepositedUST == 0) {
            return;
        }

        depositInfo.aUSTValue = i_aUST.balanceOf(user);
        uint256 timeElapsed = block.timestamp - depositInfo.lastUpdateTime;
        if (timeElapsed > 0) {
            uint256 exponent = (PRECISION * ANCHOR_INTEREST_RATE * timeElapsed) / (100 * SECONDS_PER_YEAR);
            uint256 compoundFactor = _calculateCompoundGrowth(exponent);

            depositInfo.aUSTValue = (depositInfo.aUSTValue * compoundFactor) / PRECISION;
            depositInfo.lastUpdateTime = block.timestamp;
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
