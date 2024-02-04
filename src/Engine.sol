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
    error Engine__WithdrawalFailed();
    error Engine__UnhealthyPosition();
    error Engine__ValueCannotBeZero();
    error Engine__BurnTransferFailed();
    error Engine__TokenNotAllowListed();
    error Engine__WithdrawalLimitExceeded();
    error Engine__LiquidationNotPermitted();

    //STATE VARIABLES
    mapping(address user => mapping(address token => uint256 amount)) private s_collateral;

    mapping(address token => AggregatorV3Interface priceFeed) private s_priceFeeds;

    mapping(address user => uint256 amount) private s_mintedCoins;

    mapping(address token => bool allowed) private s_allowed;

    address[] private s_supportedTokens;

    uint private immutable LTV_THRESHOLD = 70;

    Stablecoin public immutable i_stablecoin;

    //EVENTS
    event CoinsMinted(address indexed user , uint256 amount);

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    event CoinsBurned(address indexed user , uint256 amount);

    event CollateralWithdrawn(address indexed user, address indexed receiver, address indexed token, uint256 amount);

    event Liquidation(address indexed user, address indexed liquidator, uint256 amount);

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
    greaterThanZero(collateralAmount) 
    allowListedToken(collateralToken)
    {
        _addCollateralToUserPosition(collateralToken, collateralAmount);
        _mintStablecoinToUser(msg.sender, mintAmount);
    }

    function depositCollateral(
        address collateralToken,
        uint256 collateralAmount
    ) external 
    greaterThanZero(collateralAmount) 
    allowListedToken(collateralToken)
    {
        _addCollateralToUserPosition(collateralToken, collateralAmount);
    }

    function redeemCollateralForStablecoin(
        address collateralToken, 
        uint256 collateralAmount, 
        uint256 burnAmount
    ) external 
    //allowListedToken(collateralToken) : allow list only required for deposit
    greaterThanZero(collateralAmount) 
    greaterThanZero(burnAmount) 
    {
        _burnStablecoinForUser(msg.sender, burnAmount,msg.sender);
        _removeCollateralFromUserPosition(msg.sender, collateralToken, collateralAmount, msg.sender);
    }

    function redeemCollateral(
        address collateralToken, 
        uint256 collateralAmount
    ) external 
    greaterThanZero(collateralAmount) 
    {
        _removeCollateralFromUserPosition(msg.sender, collateralToken, collateralAmount, msg.sender);
    }

    function burnStablecoin(
        uint256 burnAmount
    ) external 
    greaterThanZero(burnAmount) 
    {
        _burnStablecoinForUser(msg.sender, burnAmount, msg.sender);
    }

    function liquidateUserPosition(
        address user
    ) external {
        _liquidateUserPosition(user);
    }

    function getUserLtv(
        address user
    ) external view returns(uint256 userLtv) {
        (,userLtv) = _checkPositionLtv(user);
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
        emit CollateralDeposited(msg.sender, collateralToken, collateralAmount);

        if(!successfulDeposit){
            revert Engine__DepositFailed();
        }
    }

    function _removeCollateralFromUserPosition(
        address user,
        address collateralToken,
        uint256 collateralAmount,
        address receiver
    ) private {
        uint256 userCollateral = s_collateral[user][collateralToken];

        if(userCollateral < collateralAmount){
            revert Engine__WithdrawalLimitExceeded();
        }
        s_collateral[user][collateralToken] -= collateralAmount;

        if(!_checkPositionHealthy(user)){
            revert Engine__UnhealthyPosition();
        }
        
        bool successfulWithdrawal = IERC20(collateralToken).transferFrom(address(this), receiver, collateralAmount);
        emit CollateralWithdrawn(user, receiver, collateralToken, collateralAmount);

        if(!successfulWithdrawal){
            revert Engine__WithdrawalFailed();
        }
    }

    function _mintStablecoinToUser(address user, uint256 mintAmount) private {
        s_mintedCoins[user] += mintAmount;
        if(!_checkPositionHealthy(user)){
            revert Engine__UnhealthyPosition();
        }

        bool mintSuccess = i_stablecoin.mint(user, mintAmount);

        if(!mintSuccess){
            revert Engine__MintingError();
        }

        emit CoinsMinted(user, mintAmount);
    }

    function _burnStablecoinForUser(address user, uint256 burnAmount, address sender) private {
        s_mintedCoins[user] -= burnAmount;
        i_stablecoin.approve(address(this), burnAmount);
        bool transferSuccess = i_stablecoin.transferFrom(sender, address(this), burnAmount);

        if(!transferSuccess){
            revert Engine__BurnTransferFailed();
        }

        i_stablecoin.burn(burnAmount);
        emit CoinsBurned(user, burnAmount); 
    }

    function _liquidateUserPosition(address user) private {
        if(_checkPositionHealthy(user)){
            revert Engine__LiquidationNotPermitted();
        }

        uint256 userStablecoinPosition = s_mintedCoins[user];
        _burnStablecoinForUser(user, userStablecoinPosition, msg.sender);

        for(uint256 index; index < s_supportedTokens.length;){
            address token = s_supportedTokens[index];
            uint256 userCollateralPosition = s_collateral[user][token];
            
            if(userCollateralPosition > 0){
                _removeCollateralFromUserPosition(user, token, userCollateralPosition, msg.sender);
            }
            unchecked{index++;}
        }
        emit Liquidation(user, msg.sender, userStablecoinPosition);
    }

    function _checkPositionHealthy(address user)  private view returns(bool healthy) {
        (healthy,) = _checkPositionLtv(user);
    }

    /**
     * Method used to check if users position is in a healthy state.
     * The safe Loan To Value (LTV) ratio for this protocol is <70% 
     * e.g. The user can only mint strictly less than 70% of their collateral
     * 
     * @param user address used for position check
     * @return healthy true if user's position is healthy, false otherwise
     * @return userLtv the users Loan to Value ratio as a percentage (%)
     */
    function _checkPositionLtv(address user) private view returns(bool, uint256 userLtv) {
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
        uint256 mintedCoins = s_mintedCoins[user];
        userLtv = _calculateUserLTV(totalCollateral, mintedCoins);
        
        if((totalCollateral == 0 && mintedCoins != 0) || userLtv >= LTV_THRESHOLD){
            return(false, userLtv);
        }
        return(true, userLtv);
    }

    /**
     * Calculate mintAmount as a percentage of users total collateral 
     * 
     * @param totalCollateral total value of users collateral position
     * @return ltv ratio of mintAmount / collateral as a percentage
     */
    function _calculateUserLTV(uint256 totalCollateral, uint256 mintedCoins) private pure returns(uint256) {
        if(mintedCoins == 0 && totalCollateral == 0){
            return 0;
        }else if(mintedCoins != 0 && totalCollateral == 0){
            return 2**256 - 1; //infinite LTV ... l/v = l/0 = infinity
        }
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

    function getUserCollateralPosition(address user, address token) public view returns(uint256) {
        return s_collateral[user][token];
    }
}
