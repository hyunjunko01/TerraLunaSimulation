// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Terra} from "./Terra.sol";
import {Luna} from "./Luna.sol";

contract TerraLunaEngine {
    Terra public immutable i_terra = new Terra(address(this));
    Luna public immutable i_luna = new Luna(address(this));

    uint256 public constant TERRA_PRICE = 1e18;
    uint256 public constant INITIAL_LUNA_PRICE = 1e18;
    uint256 public constant INITIAL_LUNA_SUPPLY = 10000000 * 1e18; // 10M LUNA

    uint256 public lunaPrice;
    uint256 public lunaSupply;
    uint256 public confidence;

    // the ideal price we want
    constructor() {
        lunaPrice = INITIAL_LUNA_PRICE;
        confidence = 1e18;
    }

    // UST -> LUNA (burn UST, mint LUNA)
    function swapUSTtoLUNA(uint256 ustAmount) external {
        i_terra.transferFrom(msg.sender, address(this), ustAmount); // transfer the UST in the user's account to the engine's account
        i_terra.burn(address(this), ustAmount); // burn the UST received from the user.

        // calculate exchange rate
        uint256 lunaAmount = ustAmount * TERRA_PRICE / lunaPrice;
        i_luna.mint(msg.sender, lunaAmount);

        _updateLunaPrice();
    }

    // LUNA -> UST (burn LUNA, mint UST)
    function swapLUNAtoUST(uint256 lunaAmount) external {
        i_luna.transferFrom(msg.sender, address(this), lunaAmount);
        i_luna.burn(address(this), lunaAmount);

        uint256 ustAmount = lunaAmount * lunaPrice / TERRA_PRICE;
        i_terra.mint(msg.sender, ustAmount);

        _updateLunaPrice();
    }

    /// @notice update price of LUNA
    /// this function updates the price change based on the supply.
    function _updateLunaPrice() internal {
        lunaSupply = i_luna.totalSupply();

        if (lunaSupply == 0) {
            lunaPrice = INITIAL_LUNA_PRICE;
            return;
        }

        lunaPrice = (INITIAL_LUNA_SUPPLY * INITIAL_LUNA_PRICE) / lunaSupply;
    }
}
