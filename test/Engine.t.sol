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

    function testFuzz_sucessfulMintHealthyPosition(uint256 mintAmount) public {
        //must be less than 70% tlv to succeed
        //699 tokens or less / 1000USD collateral
        vm.assume(mintAmount < 700 && mintAmount > 0);

        //token mock price = 1000 USD
        aggregatorV3Mock.setLatestPrice(1000);
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        
        // 1 token = 1000 USD total colateral
        uint256 collateralAmount = 1;

        vm.prank(user);
        engine.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
        assertEq(mintAmount, engine.getUserStablecoinPosition(user));
    }

    function testFuzz_failedMintUnhealthyPosition(uint256 mintAmount) public {
        //must be 70% tlv or higher to revert
        //700 tokens or more / 1000USD collateral
        //mintAmount must be less than 2**249 becuase it is multiplied by 100 in the health factor calculations
        //if mintAmount is 2**250 or more the uint256 will overflow during calculation
        //e.g. 
        // 2**249 * 100 < MAX_INT (uint256(-1))
        // 2**250 * 100 > MAX_INT (uint256(-1))
        vm.assume(mintAmount >= 700 && mintAmount < 2**249);

        //token mock price = 1000 USD
        aggregatorV3Mock.setLatestPrice(1000);
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        
        // 1 token = 1000 USD total colateral
        uint256 collateralAmount = 1;

        vm.expectRevert(Engine.Engine__UnhealthyPosition.selector);

        vm.prank(user);
        engine.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
    }

    function test_mintStablecoinZeroCollateral() public {
        vm.expectRevert(Engine.Engine__ValueCannotBeZero.selector);
        engine.mintStablecoin(address(1), 0, 100);
    }
}
