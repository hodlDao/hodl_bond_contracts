// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

import "./lib/SafeMath.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/IBTCH.sol";
import "./interfaces/IERC20Permit.sol";

import "./types/ERC20Permit.sol";
import "./types/HodlAccessControlled.sol";

contract HodlERC20Token is ERC20Permit, IBTCH, HodlAccessControlled {
    using SafeMath for uint256;

    constructor(address _authority)
        ERC20("Hodl", "BTCH", 9)
        ERC20Permit("Hodl")
        HodlAccessControlled(IHodlAuthority(_authority))
    {}

    function mint(address account_, uint256 amount_) external override onlyVault 
    {
        _mint(account_, amount_);
    }

    function burn(uint256 amount) external override 
    {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account_, uint256 amount_) external override 
    {
        _burnFrom(account_, amount_);
    }

    function _burnFrom(address account_, uint256 amount_) internal 
    {
        uint256 decreasedAllowance_ = allowance(account_, msg.sender).sub(
            amount_,
            "ERC20: burn amount exceeds allowance"
        );

        _approve(account_, msg.sender, decreasedAllowance_);
        _burn(account_, amount_);
    }
}
