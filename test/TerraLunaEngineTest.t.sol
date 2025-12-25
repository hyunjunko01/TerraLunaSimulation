// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Terra} from "../src/Tokens/Terra.sol";
import {Luna} from "../src/Tokens/Luna.sol";
import {TerraLunaEngine} from "../src/Protocols/SwapProtocol/TerraLunaEngine.sol";

contract TerraLunaEngineTest is Test {
    Terra private ust;
    Luna private luna;
    TerraLunaEngine private tlEngine;

    address public user = makeAddr("user");

    function setUp() public {
        tlEngine = new TerraLunaEngine();
        ust = tlEngine.i_ust();
        luna = tlEngine.i_luna();
    }
}
