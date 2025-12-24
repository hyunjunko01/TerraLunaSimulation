// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Terra} from "../../Tokens/Terra.sol";
import {Luna} from "../../Tokens/Luna.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 *     @title Terra-Luna Swap Engine - Simplified Swap Engine for UST and LUNA
 *     @notice This is the Terra-Luna Swap Engine contract, which allows users to swap between UST and LUNA tokens.
 *     The swap rates are determined by a simple supply-demand mechanism.
 *     @author Tyler Ko (Hyunjun Ko)
 */
contract TerraLunaEngine is ReentrancyGuard {
    error TerraLunaEngine__NeedsMoreThanZero();
    error TerraLunaEngine__LunaOutOfStock();
    error TerraLunaEngine__LunaPriceIsTooLow();

    Terra public immutable i_ust;
    Luna public immutable i_luna;

    uint256 public constant UST_PRICE = 1e18;
    uint256 public constant INITIAL_UST_SUPPLY = 10000000 * 1e18;
    uint256 public constant INITIAL_LUNA_PRICE = 1e18;
    uint256 public constant INITIAL_LUNA_SUPPLY = 10000000 * 1e18; // 10M LUNA
    uint256 public constant MIN_LUNA_PRICE = 0.0001 ether;

    uint256 public s_lunaPrice;
    uint256 private s_lunaSupply;

    event SwapUSTtoLUNA(address indexed user, uint256 ustAmount, uint256 lunaAmount);
    event SwapLUNAtoUST(address indexed user, uint256 lunaAmount, uint256 ustAmount);

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert TerraLunaEngine__NeedsMoreThanZero();
        }
        _;
    }

    // initial supply of LUNA is distributed to user later when this contract is deployed
    // the ideal price we want
    constructor() {
        i_ust = new Terra(address(this));
        i_luna = new Luna(address(this));

        s_lunaPrice = INITIAL_LUNA_PRICE;
        s_lunaSupply = INITIAL_LUNA_SUPPLY;
    }

    /**
     *     @notice Swap UST to LUNA, UST -> LUNA (burn UST, mint LUNA)
     *     @param ustAmount The amount of UST to swap
     */
    function swapUSTtoLUNA(uint256 ustAmount) external moreThanZero(ustAmount) nonReentrant {
        // transfer UST from user to this contract and burn UST
        i_ust.burn(msg.sender, ustAmount);

        // calculate exchange rate
        uint256 lunaAmount = ustAmount * UST_PRICE / s_lunaPrice;
        i_luna.mint(msg.sender, lunaAmount);

        // update LUNA price and supply to reflect the swap
        _updateLunaSupply(lunaAmount, true);
        _updateLunaPrice();

        emit SwapUSTtoLUNA(msg.sender, ustAmount, lunaAmount);
    }

    /**
     *     @notice Swap LUNA to UST, LUNA -> UST (burn LUNA, mint UST)
     *     @param lunaAmount The amount of LUNA to swap
     */
    function swapLUNAtoUST(uint256 lunaAmount) external moreThanZero(lunaAmount) nonReentrant {
        // transfer LUNA from user to this contract and burn LUNA
        i_luna.burn(msg.sender, lunaAmount);

        // calculate exchange rate
        uint256 ustAmount = lunaAmount * s_lunaPrice / UST_PRICE;
        i_ust.mint(msg.sender, ustAmount);

        // update LUNA price and supply to reflect the swap
        _updateLunaSupply(lunaAmount, false);
        _updateLunaPrice();

        emit SwapLUNAtoUST(msg.sender, lunaAmount, ustAmount);
    }

    //////////////////////////////////////////////
    // Private & Internal View & Pure Functions //
    //////////////////////////////////////////////

    /**
     *  @notice update supply of LUNA
     *  this function updates the supply of LUNA based on the swap.
     */
    function _updateLunaSupply(uint256 lunaAmount, bool increase) internal {
        if (increase) {
            s_lunaSupply += lunaAmount;
        } else {
            s_lunaSupply -= lunaAmount;
        }
    }

    /**
     * @notice update price of LUNA
     * this function updates the price change based on the supply.
     */
    function _updateLunaPrice() internal {
        if (s_lunaSupply == 0) revert TerraLunaEngine__LunaOutOfStock();

        uint256 newPrice = (INITIAL_LUNA_SUPPLY * INITIAL_LUNA_PRICE) / s_lunaSupply;

        // If Luna price drops below minimum threshold, revert the transaction
        if (newPrice < MIN_LUNA_PRICE) {
            revert TerraLunaEngine__LunaPriceIsTooLow();
        }

        s_lunaPrice = newPrice;
    }
}
