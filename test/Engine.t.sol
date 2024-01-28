//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Engine} from "../src/Engine.sol";
import {Stablecoin} from "../src/Stablecoin.sol";
import {TokenMock} from "./mock/TokenMock.sol";
import {AggregatorV3Mock} from "./mock/AggregatorV3Mock.sol";

contract EngineTest is Test {

    Engine private engine;
    Stablecoin private stablecoin;
    TokenMock private collateralTokenMock;
    AggregatorV3Mock private aggregatorV3Mock;

    address private owner = makeAddr("owner");
    address private user = makeAddr("user");

    function setUp() public {
        vm.startBroadcast(owner);
        stablecoin = new Stablecoin();
        engine = new Engine(address(stablecoin));

        collateralTokenMock = new TokenMock();
        aggregatorV3Mock = new AggregatorV3Mock(1000);

        //allow engine to mint new coins on stablecoin contract
        stablecoin.transferOwnership(address(engine));
        vm.stopBroadcast();
    }

    // function testFuzz_mintStablecoinNoCollateral(uint256 collateralAmount, uint256 mintAmount) public {
    //     vm.assume(mintAmount > 0 && collateralAmount > 0);
    //     vm.prank(user);
    //     engine.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
    //     assertEq(mintAmount, engine.getUserStablecoinPosition(user));
    // }

    function test_sucessfulMintHealthyPosition() public {
        //token mock price = 1000 USD
        aggregatorV3Mock.setLatestPrice(1000);
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        
        // 1 token = 1000 USD total colateral
        uint256 collateralAmount = 1;

        // mint 700 tokens = 70% LTV ratio
        uint256 mintAmount = 700; 

        vm.prank(user);
        engine.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
        assertEq(mintAmount, engine.getUserStablecoinPosition(user));
    }

    function test_mintStablecoinZeroCollateral() public {
        vm.expectRevert(Engine.Engine__ValueCannotBeZero.selector);
        engine.mintStablecoin(address(1), 0, 100);
    }
}
