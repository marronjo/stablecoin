//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Engine} from "../src/Engine.sol";
import {Stablecoin} from "../src/Stablecoin.sol";
import {TokenMock} from "./mock/TokenMock.sol";

contract EngineTest is Test {

    Engine private engine;
    Stablecoin private stablecoin;
    TokenMock private collateralTokenMock;

    address private owner = makeAddr("owner");
    address private user = makeAddr("user");

    function setUp() public {
        vm.startBroadcast(owner);
        collateralTokenMock = new TokenMock();
        stablecoin = new Stablecoin();
        engine = new Engine(address(stablecoin));

        stablecoin.transferOwnership(address(engine));
        vm.stopBroadcast();
    }

    function testFuzz_mintCorrectStablecoinAmount(uint256 collateralAmount, uint256 mintAmount) public {
        vm.assume(mintAmount > 0 && collateralAmount > 0);
        vm.prank(user);
        engine.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
        assertEq(mintAmount, engine.getUserStablecoinPosition(user));
    }

    function test_mintStablecoinZeroCollateral() public {
        vm.expectRevert(Engine.Engine__ValueCannotBeZero.selector);
        engine.mintStablecoin(address(1), 0, 100);
    }
}