// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

import "./lib/SafeERC20.sol";
import "./lib/SafeMath.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IDistributor.sol";
import "./interfaces/IsBTCH.sol";

import "./types/HodlAccessControlled.sol";

contract Distributor is IDistributor, HodlAccessControlled {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    event InfoRateSet(uint256 infoRate);

    address public immutable sbtch;
    address public immutable staking;
    uint256 public constant rateDenominator = 1_000_000;
    uint256 public infoRate = 400; // in 1_000_000: ( 1000 = 0.1% )

    constructor(
        address _sbtch,
        address _staking,
        address _authority
    ) HodlAccessControlled(IHodlAuthority(_authority)) {
        require(_sbtch != address(0), "ZeroAddress:sBTCH");
        sbtch = _sbtch;
        require(_staking != address(0), "ZeroAddress:Staking");
        staking = _staking;
    }

    function distributeAmount() external view override returns (uint256) {
        return IsBTCH(sbtch).circulatingSupply().mul(infoRate).div(rateDenominator);
    }

    function setInfoRate(uint256 _infoRate) external override onlyGovernorPolicy {
        require(_infoRate <= 1_000_000, "Too much");
        infoRate = _infoRate;
        
        emit InfoRateSet(_infoRate);
    }

}
