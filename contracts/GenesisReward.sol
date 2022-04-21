// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.4;

import "./interfaces/IERC20.sol";
import "./lib/SafeERC20.sol";
import "./lib/SafeMath.sol";

import "./types/HodlAccessControlled.sol";

import "./interfaces/IGenesis.sol";
import "./interfaces/INoteKeeper.sol";
import "./interfaces/IBondDepository.sol";

contract GenesisReward is HodlAccessControlled {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    address public immutable targetToken;
    address public immutable genesis;
    address public immutable bondDepository;
    
    constructor(IHodlAuthority _authority, address pTargetToken, address pGenesis, address pBondDepository) HodlAccessControlled(_authority) {
        targetToken = pTargetToken;
        genesis = pGenesis;
        bondDepository = pBondDepository;
    }
    
    function handleGenesis()
        external
        onlyGovernorPolicy
    {
        uint tokenBalance = IERC20(targetToken).balanceOf(genesis);
        
        IGenesis(genesis).withdrawGenesis();
        IERC20(targetToken).safeApprove(bondDepository, tokenBalance);
        IBondDepository(bondDepository).depositForGenesis(authority.genesisMarketID(), tokenBalance, authority.genesisLength(), authority.bondLength(), address(0));
    }
 
}
