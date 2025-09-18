// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Terra} from "../../src/Tokens/Terra.sol";
import {Luna} from "../../src/Tokens/Luna.sol";
import {TerraLunaEngine} from "../../src/Protocols/SwapProtocol/TerraLunaEngine.sol";
import {LUNAStakingSystem} from "../../src/Protocols/AnchorProtocol/LUNAStakingSystem.sol";
import {USTDepositSystem} from "../../src/Protocols/AnchorProtocol/USTDepositSystem.sol";
import {USTLoanSystem} from "../../src/Protocols/AnchorProtocol/USTLoanSystem.sol";

contract DeployTerraLuna is Script {
    function run() external returns (Terra, Luna, TerraLunaEngine) {
        vm.startBroadcast();
        TerraLunaEngine engine = new TerraLunaEngine();
        Terra terra = engine.i_ust();
        Luna luna = engine.i_luna();
        vm.stopBroadcast();
        return (terra, luna, engine);
    }
}
