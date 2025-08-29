// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Terra} from "../src/Terra.sol";
import {Luna} from "../src/Luna.sol";
import {TerraLunaEngine} from "../src/TerraLunaEngine.sol";

contract DeployTerraLuna is Script {
    function run() external returns (Terra, Luna, TerraLunaEngine) {
        vm.startBroadcast();
        TerraLunaEngine engine = new TerraLunaEngine();
        Terra terra = engine.i_terra();
        Luna luna = engine.i_luna();
        vm.stopBroadcast();
        return (terra, luna, engine);
    }
}
