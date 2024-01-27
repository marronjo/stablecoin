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

/**
 * @title Stabelcoin Algorithm Engine
 * @author Joe Marron
 * 
 * This engine is designed to keep the stablecoin at the price of 1$ 
 */
contract Engine is IEngine {

    error Engine__ValueCannotBeZero();
    error Engine__TokenNotAllowListed();

    struct TokenData{
        address priceFeed;
        bool allowed;
    }

    mapping(address token => TokenData tokenData) private s_tokens;

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

    constructor(){}

    function MintStablecoin(
        address collateralToken,
        uint256 collateralAmount,
        uint256 mintAmount
    ) external 
    greaterThanZero(collateralAmount) 
    allowListedToken(collateralToken) {

    }

    function depositCollateral(
        address collateralToken,
        uint256 collateralAmount
    ) external 
    greaterThanZero(collateralAmount) 
    allowListedToken(collateralToken) {

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

}