// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.4;

import "../lib/SafeERC20.sol";
import "../types/HodlAccessControlled.sol";
import "../interfaces/IERC20.sol";

abstract contract FrontEndRewarder is HodlAccessControlled {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public rewards; // front end operator rewards
    mapping(address => bool) public whitelisted; // whitelisted status for operators

    IERC20 internal immutable btch; // reward token

    constructor(IHodlAuthority _authority, IERC20 _btch) HodlAccessControlled(_authority) {
        btch = _btch;
    }

    function getReward() external 
    {
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        btch.safeTransfer(msg.sender, reward);
    }

    // give reward data for new market payout to user data
    function _giveRewards(uint256 _payout, address _referral) internal 
        returns (uint256 toGen, uint256 toStaking, uint256 toDev, uint256 toRef) 
    {
        toStaking = (_payout * authority.stakingReward()) / 1e4;
        (toGen, toStaking, toDev, toRef) = _giveRewardsForStakingReward(toStaking, _referral);
    }
    
    // give reward data for staking reward
    function _giveRewardsForStakingReward(uint256 _toStaking, address _referral) internal 
        returns (uint256 toGen, uint256 toStaking, uint256 toDev, uint256 toRef) 
    {
        toStaking = _toStaking;
        toGen = (_toStaking * authority.genReward()) / 1e4;
        toDev = (_toStaking * authority.devReward()) / 1e4;
        toRef = (_toStaking * authority.refReward()) / 1e4;

        if (whitelisted[_referral]) {
            rewards[_referral] += toRef;
        }
        else {
            toRef = 0;
        }
    }

    function whitelist(address _operator) external onlyGovernorPolicy 
    {
        whitelisted[_operator] = !whitelisted[_operator];
    }
}
