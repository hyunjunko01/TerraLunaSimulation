// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TerraLunaEngine} from "../Protocols/SwapProtocol/TerraLunaEngine.sol";

/*
    @title Terra Token (UST) - Stablecoin Token pegged to 1 USD
    @notice This is the UST token contract, which is a simplified version of the Terra stablecoin.
    The minting and burning of UST tokens are controlled by the TerraLunaEngine contract.
    @author Tyler Ko (Hyunjun Ko)
*/

contract Terra is ERC20 {
    error Terra__NotEngine();

    address private immutable i_engine;

    // Only the engine has the authority to mint and burn tokens.
    // User can swap each token by calling function in the engine code.

    modifier onlyEngine() {
        if (msg.sender != i_engine) {
            revert Terra__NotEngine();
        }
        _;
    }

    constructor(address _engine) ERC20("Terra", "UST") {
        i_engine = _engine;
    }

    function burn(address from, uint256 amount) external onlyEngine {
        _burn(from, amount);
    }

    function mint(address to, uint256 amount) external onlyEngine {
        _mint(to, amount);
    }
}
