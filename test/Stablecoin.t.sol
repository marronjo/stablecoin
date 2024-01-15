//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Stablecoin} from "../src/Stablecoin.sol";

contract StablecoinTest is Test {

    Stablecoin private stablecoin;

    address private owner = makeAddr("owner");
    address private user = makeAddr("user");

    modifier mintTokensForOwner(uint256 amount){
        vm.prank(owner);
        stablecoin.mint(owner, amount);
        _;
    }

    function setUp() public {
        vm.startBroadcast(owner);
        stablecoin = new Stablecoin();
        vm.stopBroadcast();
    }

    function test_successfulMint() public {
        vm.prank(owner);
        assert(stablecoin.mint(user, 1000) == true);
    }

    function test_zeroAddressMint() public {
        vm.prank(owner);
        vm.expectRevert(Stablecoin.Stablecoin__NotZeroAddress.selector);
        stablecoin.mint(address(0), 5000);
    }

    function test_zeroAmountMint() public {
        vm.prank(owner);
        vm.expectRevert(Stablecoin.Stablecoin__AmountMustBeGreaterThanZero.selector);
        stablecoin.mint(user, 0);
    }

    function test_successfulBurn() public mintTokensForOwner(100) {
        vm.prank(owner);
        stablecoin.burn(100);
    }

    function test_burnZeroAmount() public mintTokensForOwner(100) {
        vm.prank(owner);
        vm.expectRevert(Stablecoin.Stablecoin__AmountMustBeGreaterThanZero.selector);
        stablecoin.burn(0);
    }

    function test_burnExceedsBalance() public mintTokensForOwner(500) {
        vm.prank(owner);
        vm.expectRevert(Stablecoin.Stablecoin__BurnAmountExceedsBalance.selector);
        stablecoin.burn(600);
    }
}