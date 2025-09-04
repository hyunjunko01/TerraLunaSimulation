// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AnchorProtocol} from "./AnchorProtocol.sol";

contract AnchorUST is ERC20 {
    error AnchorUST__NotAnchor();

    address private immutable i_anchor;

    // Only the Anchor Protocol has the power to mint and burn each token.
    // This token is minted when users deposit UST to Anchor Protocol.
    // This token is burned when users withdraw UST from Anchor Protocol.

    modifier onlyAnchor() {
        if (msg.sender != i_anchor) {
            revert AnchorUST__NotAnchor();
        }
        _;
    }

    constructor(address _anchor) ERC20("AnchorUST", "aUST") {
        i_anchor = _anchor;
    }

    function burn(address from, uint256 amount) external onlyAnchor {
        _burn(from, amount);
    }

    function mint(address to, uint256 amount) external onlyAnchor {
        _mint(to, amount);
    }
}
