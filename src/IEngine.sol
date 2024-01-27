//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IEngine {

    function MintStablecoin(address collateralToken, uint256 collateralAmount) external; 

    function depositCollateral(address collateralToken, uint256 collateralAmount) external;

    function redeemCollateral(address collateralToken, uint256 collateralAmount) external;

    function burnStablecoin() external;
    
    function liquidate() external;
    
    function getHealthFactor() external view;
    
}
