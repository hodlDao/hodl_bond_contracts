// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

import "./interfaces/IHodlAuthority.sol";

import "./types/HodlAccessControlled.sol";

contract HodlAuthority is IHodlAuthority, HodlAccessControlled {
    address public override governor;
    address public override guardian;
    address public override policy;
    address public override vault;

    address public newGovernor;
    address public newGuardian;
    address public newPolicy;
    address public newVault;
    
    uint256 public override genesisMarketID = 0;
    
    uint256 public override stakingReward = 2500;// % reward for staking reward (4 decimals: 100 = 1%)
    uint256 public override genReward = 3000;    // % reward for genesis based on staking reward (4 decimals: 100 = 1%)
    uint256 public override devReward = 1500;    // % reward for dev based on staking reward (4 decimals: 100 = 1%)
    uint256 public override refReward = 0;       // % reward for referrer based on staking reward (4 decimals: 100 = 1%)

    uint256 public override genesisLength = 3600*24*180; //180 days
    uint256 public override bondLength = 3600*24*7;      //7 days
    
    uint256 public override unstakeClaimMax = 1000000e9;
    
    
    enum UINTTYPE {
        STAKINGREWARD,
        GENREWARD,
        DEVREWARD,
        REFREWARD,
        GENESISLENGTH,
        BONDLENGTH,
        UNSTAKECLAIMMAX
    }

    constructor(
        address _governor,
        address _guardian,
        address _policy,
        address _vault
    ) HodlAccessControlled(IHodlAuthority(address(this))) {
        governor = _governor;
        emit GovernorPushed(address(0), governor, true);
        guardian = _guardian;
        emit GuardianPushed(address(0), guardian, true);
        policy = _policy;
        emit PolicyPushed(address(0), policy, true);
        vault = _vault;
        emit VaultPushed(address(0), vault, true);
    }

    function pushGovernor(address _newGovernor, bool _effectiveImmediately) external onlyGovernor {
        if (_effectiveImmediately) governor = _newGovernor;
        newGovernor = _newGovernor;
        emit GovernorPushed(governor, newGovernor, _effectiveImmediately);
    }

    function pushGuardian(address _newGuardian, bool _effectiveImmediately) external onlyGovernor {
        if (_effectiveImmediately) guardian = _newGuardian;
        newGuardian = _newGuardian;
        emit GuardianPushed(guardian, newGuardian, _effectiveImmediately);
    }

    function pushPolicy(address _newPolicy, bool _effectiveImmediately) external onlyGovernor {
        if (_effectiveImmediately) policy = _newPolicy;
        newPolicy = _newPolicy;
        emit PolicyPushed(policy, newPolicy, _effectiveImmediately);
    }

    function pushVault(address _newVault, bool _effectiveImmediately) external onlyGovernor {
        if (_effectiveImmediately) vault = _newVault;
        newVault = _newVault;
        emit VaultPushed(vault, newVault, _effectiveImmediately);
    }

    function pullGovernor() external {
        require(msg.sender == newGovernor, "!newGovernor");
        emit GovernorPulled(governor, newGovernor);
        governor = newGovernor;
    }

    function pullGuardian() external {
        require(msg.sender == newGuardian, "!newGuard");
        emit GuardianPulled(guardian, newGuardian);
        guardian = newGuardian;
    }

    function pullPolicy() external {
        require(msg.sender == newPolicy, "!newPolicy");
        emit PolicyPulled(policy, newPolicy);
        policy = newPolicy;
    }

    function pullVault() external {
        require(msg.sender == newVault, "!newVault");
        emit VaultPulled(vault, newVault);
        vault = newVault;
    }
    
    function setParameter(uint _paramType, uint paramValue) 
        external 
        override
        onlyGovernor 
    {
        UINTTYPE paramType = UINTTYPE(_paramType);
        require(paramType >= UINTTYPE.STAKINGREWARD && paramType <= UINTTYPE.UNSTAKECLAIMMAX, "OutOfRange");
        
        if(paramType == UINTTYPE.STAKINGREWARD) 
        {
            stakingReward = paramValue;
        }
        else if(paramType == UINTTYPE.GENREWARD) 
        {
            genReward = paramValue;
        }
        else if(paramType == UINTTYPE.DEVREWARD) 
        {
            devReward = paramValue;
        }
        else if(paramType == UINTTYPE.REFREWARD) 
        {
            refReward = paramValue;
        }
        else if(paramType == UINTTYPE.GENESISLENGTH) 
        {
            genesisLength = paramValue;
        }
        else if(paramType == UINTTYPE.BONDLENGTH) 
        {
            bondLength = paramValue;
        }
        else if(paramType == UINTTYPE.UNSTAKECLAIMMAX) 
        {
            unstakeClaimMax = paramValue;
        }
    }
}
