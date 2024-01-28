//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Stablecoin
 * @author Joe Marron
 * Algorithmic stabelcoin with crypto as collateral
 * 
 * ERC20 implementation of the stablecoin, no logic within this contract
 */
contract Stablecoin is ERC20Burnable, Ownable { 

    error Stablecoin__AmountMustBeGreaterThanZero();
    error Stablecoin__BurnAmountExceedsBalance();
    error Stablecoin__NotZeroAddress();

    address[] private minters;
    
    constructor() ERC20("Stablecoin", "STB") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if(_amount <= 0) {
            revert Stablecoin__AmountMustBeGreaterThanZero();
        }
        if(balance < _amount) {
            revert Stablecoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns(bool) {
        if(_to == address(0)) {
            revert Stablecoin__NotZeroAddress();
        }
        if(_amount <= 0) {
            revert Stablecoin__AmountMustBeGreaterThanZero();
        }
        _mint(_to, _amount);
        minters.push(_to);
        return true;
    }

    function getMinters() external view returns(address[] memory){
        return minters;
    }
}