// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TerraLunaEngine} from "../Protocols/SwapProtocol/TerraLunaEngine.sol";

/*
    @title Luna Token (LUNA) - token that can make UST stable
    @notice This is the LUNA token contract, which is a simplified version of the native token of the Terra blockchain.
    The minting and burning of LUNA tokens are controlled by the TerraLunaEngine contract.
    @author Tyler Ko (Hyunjun Ko)
*/

contract Luna is ERC20 {
    error Luna__NotEngine();

    address private immutable i_engine;

    // Only the engine has the authority to mint and burn tokens.
    // User can swap each token by calling function in the engine code.

    modifier onlyEngine() {
        if (msg.sender != i_engine) {
            revert Luna__NotEngine();
        }
        _;
    }

    constructor(address _engine) ERC20("Luna", "LUNA") {
        i_engine = _engine;
    }

    function burn(address from, uint256 amount) external onlyEngine {
        _burn(from, amount);
    }

    function mint(address to, uint256 amount) external onlyEngine {
        _mint(to, amount);
    }
}
