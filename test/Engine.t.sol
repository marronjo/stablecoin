//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Engine} from "../src/Engine.sol";
import {Stablecoin} from "../src/Stablecoin.sol";
import {TokenMock} from "./mock/TokenMock.sol";
import {AggregatorV3Mock} from "./mock/AggregatorV3Mock.sol";
import {StablecoinMock} from "./mock/StablecoinMock.sol";

contract EngineTest is Test {

    Engine private engine;
    Stablecoin private stablecoin;
    TokenMock private collateralTokenMock;
    AggregatorV3Mock private aggregatorV3Mock;

    TokenMock private collateralTokenMock2;
    AggregatorV3Mock private aggregatorV3Mock2;

    Engine private engineMock;
    StablecoinMock private stablecoinMock;

    address private owner = makeAddr("owner");
    address private user = makeAddr("user");

    function setUp() public {
        vm.startBroadcast(owner);
        stablecoin = new Stablecoin();
        engine = new Engine(address(stablecoin));

        collateralTokenMock = new TokenMock();
        aggregatorV3Mock = new AggregatorV3Mock(1000);

        collateralTokenMock2 = new TokenMock();
        aggregatorV3Mock2 = new AggregatorV3Mock(50);

        stablecoinMock = new StablecoinMock();
        engineMock = new Engine(address(stablecoinMock));
        stablecoinMock.transferOwnership(address(engineMock));

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

    function test_sucessfulMintHealthyPositionMultipleTokens() public {
        //token mock price = 1000 USD
        aggregatorV3Mock.setLatestPrice(1000);
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        engine.addAllowListedToken(address(collateralTokenMock2), address(aggregatorV3Mock2));
        
        uint256 mintAmount = 600;

        // 1 token = 1000 USD total colateral
        uint256 collateralAmount = 1;

        vm.prank(user);
        engine.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
        assertEq(mintAmount, engine.getUserStablecoinPosition(user));
    }

    function test_failedMintZeroCollateral() public {
        uint256 mintAmount = 600;

        aggregatorV3Mock.setLatestPrice(0);
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        
        uint256 collateralAmount = 1;

        vm.expectRevert(Engine.Engine__UnhealthyPosition.selector);

        vm.prank(user);
        engine.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
    }

    function testFuzz_failedMintUnhealthyPosition(uint256 mintAmount) public {
        //must be 70% tlv or higher to revert
        //700 tokens or more / 1000USD collateral
        //mintAmount must be less than 2**249 becuase it is multiplied by 100 in the health factor calculations
        //if mintAmount is 2**250 or more the uint256 will overflow during calculation
        //e.g. 
        // 2**249 * 100 < MAX_INT 
        // 2**250 * 100 > MAX_INT
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

    function test_mintStablecoinDepositFailed() public {
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        collateralTokenMock.setTransferFailed();
        vm.expectRevert(Engine.Engine__DepositFailed.selector);
        engine.mintStablecoin(address(collateralTokenMock), 100, 50);
    }

    function test_mintStablecoinMintFailed() public {
        aggregatorV3Mock.setLatestPrice(1000);
        engineMock.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));

        //mint 500 tokens, 50% LTV ratio
        uint256 mintAmount = 500;
        
        // 1 token = 1000 USD total colateral
        uint256 collateralAmount = 1;

        stablecoinMock.setMintStatus(false);

        vm.expectRevert(Engine.Engine__MintingError.selector);

        vm.prank(user);
        engineMock.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
    }

    function test_removeTokenAllowance() public {
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        engine.removeTokenAllowance(address(collateralTokenMock));
       
        vm.expectRevert(Engine.Engine__TokenNotAllowListed.selector);

        vm.prank(user);
        engine.mintStablecoin(address(collateralTokenMock), 1, 100);
    }

    function test_addCollateralSuccess() public {
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        
        uint256 collateralAmount = 1;

        vm.prank(user);
        engine.depositCollateral(address(collateralTokenMock), collateralAmount);
        assertEq(collateralAmount, engine.getUserCollateralPosition(user, address(collateralTokenMock)));
    }

    function test_burnStablecoinSuccess() public {
       uint256 mintAmount = 20000;

        aggregatorV3Mock.setLatestPrice(300);
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        
        uint256 collateralAmount = 100;

        vm.startPrank(user);
        engine.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
        assertEq(mintAmount, engine.getUserStablecoinPosition(user));

        uint256 burnAmount = mintAmount;

        assertEq(mintAmount, stablecoin.balanceOf(user));

        stablecoin.approve(address(engine), burnAmount);

        engine.redeemCollateralForStablecoin(address(collateralTokenMock), collateralAmount, burnAmount);
        vm.stopPrank();

        assertEq(0, engine.getUserStablecoinPosition(user));
        assertEq(0, engine.getUserCollateralPosition(user, address(collateralTokenMock)));
    }

    function test_failedBurnWithdrawalLargerThanCollateral() public {
        uint256 mintAmount = 20000;

        aggregatorV3Mock.setLatestPrice(100);
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        
        uint256 collateralAmount = 300;

        uint256 burnAmount = mintAmount;

        vm.startPrank(user);
        engine.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
        assertEq(mintAmount, engine.getUserStablecoinPosition(user));

        uint256 withdrawalAmount = collateralAmount * 10;

        stablecoin.approve(address(engine), burnAmount);

        vm.expectRevert(Engine.Engine__WithdrawalLimitExceeded.selector);

        engine.redeemCollateralForStablecoin(address(collateralTokenMock), withdrawalAmount, mintAmount);
        vm.stopPrank();
    }

    function test_failedBurnUnhealthyPosition() public {
        uint256 mintAmount = 20000;

        aggregatorV3Mock.setLatestPrice(1);
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        
        uint256 collateralAmount = 30000;

        uint256 burnAmount = 5000;
        uint256 withdrawalAmount = 10000;

        //position after burn = 15000 / 15000 = 100% LTV which is not allowed

        vm.startPrank(user);
        engine.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
        assertEq(mintAmount, engine.getUserStablecoinPosition(user));

        stablecoin.approve(address(engine), burnAmount);

        vm.expectRevert(Engine.Engine__UnhealthyPosition.selector);

        engine.redeemCollateralForStablecoin(address(collateralTokenMock), withdrawalAmount, burnAmount);
        vm.stopPrank();
    }

    function test_failedBurnCollateralTransferFailed() public {
        uint256 mintAmount = 20000;

        aggregatorV3Mock.setLatestPrice(1);
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        
        uint256 collateralAmount = 30000;

        uint256 burnAmount = 5000;
        uint256 withdrawalAmount = 5000;

        vm.startPrank(user);
        engine.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
        assertEq(mintAmount, engine.getUserStablecoinPosition(user));

        stablecoin.approve(address(engine), burnAmount);
        collateralTokenMock.setTransferFailed();

        vm.expectRevert(Engine.Engine__WithdrawalFailed.selector);

        engine.redeemCollateralForStablecoin(address(collateralTokenMock), withdrawalAmount, burnAmount);
        vm.stopPrank();
    }

    function test_burnStablecoinFailedBurnTransferError() public {
       uint256 mintAmount = 20000;

        aggregatorV3Mock.setLatestPrice(300);
        engineMock.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        
        uint256 collateralAmount = 100;

        stablecoinMock.setMintStatus(true);

        vm.startPrank(user);
        engineMock.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
        assertEq(mintAmount, engineMock.getUserStablecoinPosition(user));

        uint256 burnAmount = mintAmount;

        stablecoinMock.approve(address(engineMock), burnAmount);

        stablecoinMock.setTransferFromStatus(false);

        vm.expectRevert(Engine.Engine__BurnTransferFailed.selector);

        engineMock.redeemCollateralForStablecoin(address(collateralTokenMock), collateralAmount, burnAmount);
        vm.stopPrank();
    }

    function test_burnStablecoinOnlySuccess() public {
        aggregatorV3Mock.setLatestPrice(1);
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        
        //ltv = 20k/30k = 66.6%
        uint256 mintAmount = 20000;
        uint256 collateralAmount = 30000;

        vm.startPrank(user);
        engine.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
        assertEq(mintAmount, engine.getUserStablecoinPosition(user));

        //burn 10k new ltv = 10k/30k = 33.3% safer than before
        uint256 stablecoinBurnAmount = 10000;
        stablecoin.approve(address(engine), stablecoinBurnAmount);

        engine.burnStablecoin(stablecoinBurnAmount);
        vm.stopPrank();
    }

    function test_redeemCollateralSuccess() public {
        aggregatorV3Mock.setLatestPrice(1);
        engine.addAllowListedToken(address(collateralTokenMock), address(aggregatorV3Mock));
        
        //ltv = 10k/30k = 33.3%
        uint256 mintAmount = 10000;
        uint256 collateralAmount = 30000;

        vm.startPrank(user);
        engine.mintStablecoin(address(collateralTokenMock), collateralAmount, mintAmount);
        assertEq(mintAmount, engine.getUserStablecoinPosition(user));

        //redeem 10k collateral, increase ltv from 33.3% to 10k/20k = 50% 
        uint256 collateralWithdrawalAmount = 10000;
        stablecoin.approve(address(engine), collateralWithdrawalAmount);

        engine.redeemCollateral(address(collateralTokenMock), collateralWithdrawalAmount);
        vm.stopPrank();
    }
}
