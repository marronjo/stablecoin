//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract AggregatorV3Mock is AggregatorV3Interface {

    int256 private latestPrice;

    constructor(int256 startingPrice) {
        // 1000USD + 8 decimals precision
        latestPrice = startingPrice * 1e8;
    }

    function setLatestPrice(int256 updatedPrice) external {
        latestPrice = updatedPrice * 1e8;
    }

    function decimals() external view returns (uint8) {}

    function description() external view returns (string memory) {}

    function version() external view returns (uint256) {}

    function getRoundData(
        uint80 _roundId
    ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {}

    function latestRoundData() external view
    returns (
        uint80 roundId, 
        int256 answer, 
        uint256 startedAt, 
        uint256 updatedAt, 
        uint80 answeredInRound
    ){
        return(0, latestPrice, 0, 0, 0);
    }
}
