//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IEngine {

    /**
     * Deposit collateral and mint new stablecoins.
     */
    function mintStablecoin(address collateralToken, uint256 collateralAmount, uint256 mintAmount) external; 

    /**
     * Deposit collateral and do not mint new stablecoins. Decrease Loan To Value Ratio by increasing Value of collateral.
     */
    function depositCollateral(address collateralToken, uint256 collateralAmount) external;

    /**
     * Withdraw collateral and burn stablecoins.
     */
    function redeemCollateralForStablecoin(address collateralToken, uint256 collateralAmount, uint256 stablecoinAmount) external;

    /**
     * Withdraw collateral without burning stablecoins. Increase LTV by reducing Value of collateral.
     */
    function redeemCollateral(address collateralToken, uint256 collateralAmount) external;

    /**
     * Burn stablecoin without withdrawing any collateral. Decrease LTV by reducing value of Loan.
     */
    function burnStablecoin(uint256 amount) external;
    
    /**
     * Deposit stablecoins in exchange for users entire unhealthy collateral position at a discount.
     */
    function liquidateEntirePosition(address user) external;

    /**
     * Deposit stablecoins in exchange for part of users unhealthy collateral position at a discount.
     */
    function liquidatePartialPosition(address user, address collateralToken, uint256 amountToCover) external;
    
    /**
     * Check LTV Ratio for users position, to deteremine whether liquidation is possible.
     */
    function getHealthFactor(address user) external view;

}
