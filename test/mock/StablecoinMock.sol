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
contract StablecoinMock is ERC20Burnable, Ownable { 

    error Stablecoin__AmountMustBeGreaterThanZero();
    error Stablecoin__BurnAmountExceedsBalance();
    error Stablecoin__NotZeroAddress();
    error Stablecoin__MintError();

    bool private transferFromStatus;
    bool private mintStatus;
    
    constructor() ERC20("Stablecoin", "STB") Ownable(msg.sender) {
        transferFromStatus = true;
        mintStatus = true;
    }

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

    function setMintStatus(bool status) public {
        mintStatus = status;
    }

    function mint(address /*_to*/, uint256 /*_amount*/) external view onlyOwner returns(bool) {
        return mintStatus;
    }

    function setTransferFromStatus(bool status) public {
        transferFromStatus = status;
    }

    function transferFrom(address /*from*/, address /*to*/, uint256 /*amount*/) override public view returns(bool) {
        return transferFromStatus;
    }
}