//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IEngine {

    function mintStablecoin(address collateralToken, uint256 collateralAmount, uint256 mintAmount) external; 

    function depositCollateral(address collateralToken, uint256 collateralAmount) external;

    function redeemCollateralForStablecoin(address collateralToken, uint256 collateralAmount, uint256 stablecoinAmount) external;

    function redeemCollateral(address collateralToken, uint256 collateralAmount) external;

    function burnStablecoin(uint256 amount) external;
    
    function liquidateEntirePosition(address user) external;

    function liquidatePartialPosition(address user, address collateralToken, uint256 amountToCover) external;
    
    function getHealthFactor(address user) external view;

}
