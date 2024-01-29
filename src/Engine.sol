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
 * @title Stablecoin Algorithm Engine
 * @author Joe Marron
 * 
 * This engine is designed to keep the stablecoin at the price of 1$ 
 */
contract Engine is IEngine {

    //ERRORS
    error Engine__MintingError();
    error Engine__DepositFailed();
    error Engine__UnhealthyPosition();
    error Engine__ValueCannotBeZero();
    error Engine__TokenNotAllowListed();
    error Engine__MintingThresholdBreach();

    //STATE VARIABLES
    mapping(address user => mapping(address token => uint256 amount)) private s_collateral;

    mapping(address token => AggregatorV3Interface priceFeed) private s_priceFeeds;

    mapping(address user => uint256 amount) private s_mintedCoins;

    mapping(address token => bool allowed) private s_allowed;

    address[] private s_supportedTokens;

    uint private immutable LTV_THRESHOLD = 70;

    Stablecoin public immutable i_stablecoin;

    //MODIFIERS
    modifier greaterThanZero(uint256 amount){
        if(amount == 0){
            revert Engine__ValueCannotBeZero();
        }
        _;
    }

    modifier allowListedToken(address token){
        if(!s_allowed[token]){
            revert Engine__TokenNotAllowListed();
        }
        _;
    }

    //FUNCTIONS
    constructor(address stablecoinAddress){
        i_stablecoin = Stablecoin(stablecoinAddress);
    }

    //EXTERNAL FUNCTIONS
    function mintStablecoin(
        address collateralToken,
        uint256 collateralAmount,
        uint256 mintAmount
    ) external 
    greaterThanZero(collateralAmount) {
        _addCollateralToUserPosition(collateralToken, collateralAmount);
        _mintStablecoinToUser(msg.sender, mintAmount);
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

    function addAllowListedToken(address token, address priceFeed) external {
        s_allowed[token] = true;
        s_supportedTokens.push(token);
        s_priceFeeds[token] = AggregatorV3Interface(priceFeed);
    }

    function removeTokenAllowance(address token) external {
        s_allowed[token] = false;  
    }

    //PRIVATE FUNCTIONS
    function _addCollateralToUserPosition(
        address collateralToken,
        uint256 collateralAmount
    ) private {
        s_collateral[msg.sender][collateralToken] += collateralAmount;
        bool successfulDeposit = IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);
        if(!successfulDeposit){
            revert Engine__DepositFailed();
        }
    }

    function _checkMintTokenThreshold(
        address collateralToken,
        uint256 collateralAmount,
        uint256 mintAmount
    ) private {
        
    }

    function _mintStablecoinToUser(address user, uint256 mintAmount) private {
        s_mintedCoins[user] += mintAmount;
        if(!_checkPositionHealth(user)){
            revert Engine__UnhealthyPosition();
        }
        bool mintSuccess = i_stablecoin.mint(user, mintAmount);
        if(!mintSuccess){
            revert Engine__MintingError();
        }
    }

    /**
     * Method used to check if users position is in a healthy state.
     * The safe Loan To Value (LTV) ratio for this protocol is <70% 
     * e.g. The user can only mint strictly less than 70% of their collateral
     * 
     * @param user address used for position check
     * @return true if user's position is healthy, false otherwise
     */
    function _checkPositionHealth(address user) private view returns(bool) {
        uint256 totalCollateral;
        for(uint256 index = 0; index < s_supportedTokens.length; index++){
            address token = s_supportedTokens[index];
            uint256 userCollateralPosition = s_collateral[user][token];
            if(userCollateralPosition > 0){
                (,int256 tokenPrice,,,) = s_priceFeeds[token].latestRoundData();
                uint256 normalisedTokenPrice = uint256(tokenPrice * 1e10);
                totalCollateral += (normalisedTokenPrice * userCollateralPosition) / 1e18;
            }
        }
        if(totalCollateral == 0 || _calculatePositionThreshold(totalCollateral) >= LTV_THRESHOLD){
            return false;
        }
        return true;
    }

    /**
     * Calculate mintAmount as a percentage of users total collateral 
     * 
     * @param totalCollateral total value of users collateral position
     * @return ltv ratio of mintAmount / collateral as a percentage
     */
    function _calculatePositionThreshold(uint256 totalCollateral) private view returns(uint256) {
        uint256 mintedCoins = s_mintedCoins[msg.sender];
        return (mintedCoins * 100) / totalCollateral;
    }

    //VIEW FUNCTIONS
    /**
     * Used to fetch user's stablecoin position stored in Engine contract
     * 
     * @param user position to check
     * @return stablecoin position of given user
     */
    function getUserStablecoinPosition(address user) public view returns(uint256) {
        return s_mintedCoins[user];
    }
}
