// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Terra} from "../../src/Tokens/Terra.sol";
import {Luna} from "../../src/Tokens/Luna.sol";
import {TerraLunaEngine} from "../../src/Protocols/SwapProtocol/TerraLunaEngine.sol";
import {DeployTerraLuna} from "../../script/deployment/DeployTerraLuna.s.sol";

contract SwapEngineTest is Test {
    Terra ust;
    Luna luna;
    TerraLunaEngine engine;
    DeployTerraLuna dtl;
    address user;

    uint256 public constant UST_INITIAL_SUPPLY = 100 * 1e18;
    uint256 public constant LUNA_INITIAL_SUPPLY = 100 * 1e18;

    function setUp() public {
        // 테스트용 유저 주소 생성
        user = makeAddr("user");

        // Engine, Terra, Luna 배포
        dtl = new DeployTerraLuna();
        (ust, luna, engine) = dtl.run();

        // Engine 내부 함수를 통해 테스트용 유저에게 초기 토큰 발행
        engine.mintToUserForTest(user, UST_INITIAL_SUPPLY, LUNA_INITIAL_SUPPLY);

        // sanity check
        assertEq(ust.balanceOf(user), UST_INITIAL_SUPPLY);
        assertEq(luna.balanceOf(user), LUNA_INITIAL_SUPPLY);
    }

    // ustAmount만큼
    function testSwapUSTtoLUNA() public {
        uint256 ustAmount = 10 * 1e18;
        uint256 lunaReceived = ustAmount * engine.UST_PRICE() / engine.s_lunaPrice();

        // user가 approve 필요
        vm.prank(user);
        ust.approve(address(engine), ustAmount);

        vm.prank(user);
        engine.swapUSTtoLUNA(ustAmount);

        // swap 후 잔액 체크
        assertEq(luna.balanceOf(user), LUNA_INITIAL_SUPPLY + lunaReceived);
        assertEq(ust.balanceOf(user), UST_INITIAL_SUPPLY - ustAmount);
    }

    function testSwapLUNAtoUST() public {
        uint256 lunaAmount = 10 * 1e18;
        uint256 ustReceived = lunaAmount * engine.s_lunaPrice() / engine.UST_PRICE();

        vm.prank(user);
        luna.approve(address(engine), lunaAmount);

        vm.prank(user);
        engine.swapLUNAtoUST(lunaAmount);

        // swap 후 잔액 체크
        assertEq(ust.balanceOf(user), UST_INITIAL_SUPPLY + ustReceived);
        assertEq(luna.balanceOf(user), LUNA_INITIAL_SUPPLY - lunaAmount);
    }
}
