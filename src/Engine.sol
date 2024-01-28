// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IEngine} from "./IEngine.sol";
import {Stablecoin} from "./Stablecoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title Stabelcoin Algorithm Engine
 * @author Joe Marron
 * 
 * This engine is designed to keep the stablecoin at the price of 1$ 
 */
contract Engine is IEngine {

    error Engine__ValueCannotBeZero();
    error Engine__TokenNotAllowListed();
    error Engine__ErrorDepositingTokens();
    error Engine__MintingThresholdBreach();
    error Engine__MintingError();

    struct TokenData{
        AggregatorV3Interface priceFeed;
        bool allowed;
    }

    mapping(address user => mapping(address token => uint256 amount)) private s_collateral;

    mapping(address token => TokenData tokenData) private s_tokens;

    mapping(address user => uint256 amount) private s_mintedCoins;

    uint private immutable THRESHOLD = 70;

    Stablecoin public immutable i_stablecoin;

    modifier greaterThanZero(uint256 amount){
        if(amount == 0){
            revert Engine__ValueCannotBeZero();
        }
        _;
    }

    modifier allowListedToken(address token){
        if(s_tokens[token].allowed == false){
            revert Engine__TokenNotAllowListed();
        }
        _;
    }

    constructor(address stablecoinAddress){
        i_stablecoin = Stablecoin(stablecoinAddress);
    }

    function mintStablecoin(
        address collateralToken,
        uint256 collateralAmount,
        uint256 mintAmount
    ) external 
    greaterThanZero(collateralAmount) {
        _addCollateralToUserPosition(collateralToken, collateralAmount);
        _mintStablecoinToUser(mintAmount);
    }

    function depositCollateral(
        address collateralToken,
        uint256 collateralAmount
    ) external 
    greaterThanZero(collateralAmount) {
        _addCollateralToUserPosition(collateralToken, collateralAmount);
    }

    function redeemCollateralForStablecoin(
        address collateralToken, 
        uint256 collateralAmount, 
        uint256 stablecoinAmount
    ) external {

    }

    function redeemCollateral(
        address collateralToken, 
        uint256 collateralAmount
    ) external {

    }

    function burnStablecoin(
        uint256 amount
    ) external {

    }

    function liquidateEntirePosition(
        address user
    ) external {

    }

    function liquidatePartialPosition(
        address user, 
        address collateralToken, 
        uint256 amountToCover
    ) external {

    }

    function getHealthFactor(
        address user
    ) external view {

    }

    function _addCollateralToUserPosition(
        address collateralToken,
        uint256 collateralAmount
    ) private {
        s_collateral[msg.sender][collateralToken] += collateralAmount;
        bool successfulDeposit = IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);
        if(!successfulDeposit){
            revert Engine__ErrorDepositingTokens();
        }
    }

    function _checkMintTokenThreshold(
        address collateralToken,
        uint256 collateralAmount,
        uint256 mintAmount
    ) private {
        
    }

    function _mintStablecoinToUser(uint256 mintAmount) private {
        s_mintedCoins[msg.sender] += mintAmount;
        bool mintSuccess = i_stablecoin.mint(msg.sender, mintAmount);
        if(!mintSuccess){
            revert Engine__MintingError();
        }
    }

    function getUserStablecoinPosition(address user) public view returns(uint256) {
        return s_mintedCoins[user];
    }
}
