// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

import "./lib/SafeMath.sol";
import "./lib/SafeERC20.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/IsBTCH.sol";
import "./interfaces/IDistributor.sol";
import "./interfaces/IBondDepository.sol";

import "./types/HodlAccessControlled.sol";

contract HodlStaking is HodlAccessControlled {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event DistributorSet(address distributor);
    event BondDepositorySet(address bondDepository);

    struct Epoch {
        uint256 length;     // in seconds
        uint256 number;     // since inception
        uint256 end;        // timestamp
        uint256 lastUpdate; // timestmap
        uint256 distribute; // amount
    }
    
    uint256 public unstakeAmountUsed;

    IERC20 public immutable BTCH;
    IsBTCH public immutable sBTCH;

    bool public rebaseEnabled;
    Epoch public epoch;
    IDistributor public distributor;
    IBondDepository public bondDepository;

    constructor(
        address _btch,
        address _sBTCH,
        uint256 _epochLength,
        uint256 _firstEpochNumber,
        uint256 _firstEpochTime,
        address _authority
    ) HodlAccessControlled(IHodlAuthority(_authority)) 
    {
        require(_btch != address(0), "ZeroAddress:BTCH");
        BTCH = IERC20(_btch);
        require(_sBTCH != address(0), "ZeroAddress:sBTCH");
        sBTCH = IsBTCH(_sBTCH);

        epoch = Epoch({length: _epochLength, number: _firstEpochNumber, end: _firstEpochTime, lastUpdate: 0, distribute: 0});
    }

    //stake BTCH for sBTCH.
    function stake(address _to, uint256 _amount) external returns (uint256 amount_) 
    {
        if(msg.sender != address(bondDepository))
            rebase();
            
        amount_ = _amount;
        
        BTCH.safeTransferFrom(msg.sender, address(this), amount_);
        IERC20(address(sBTCH)).safeTransfer(_to, amount_); //send as sBTCH
    }

    //requet to redeem sBTCH for BTCHs
    function unstake(address _to, uint256 _amount) external returns (uint256 amount_) 
    {
        if(msg.sender != address(bondDepository))
            rebase();
            
        amount_ = _amount;
        
        require(_amount + unstakeAmountUsed <= authority.unstakeClaimMax(), "UnstakeClaimMax");
        
        unstakeAmountUsed += amount_;
        
        IERC20(address(sBTCH)).safeTransferFrom(msg.sender, address(this), amount_);
        require(amount_ <= BTCH.balanceOf(address(this)), "Insufficient BTCH balance in contract");
        BTCH.safeTransfer(_to, amount_);
    }
    
    //trigger rebase if epoch over
    function rebase() public 
    {
        require(rebaseEnabled, "RebaseNotEnabled");
        
        if(epoch.end <= block.timestamp && epoch.lastUpdate < block.timestamp) {
            unstakeAmountUsed = 0;
            
            uint256 rewardAmount;
            
            sBTCH.rebase(epoch.distribute, epoch.number);

            epoch.end = epoch.end.add(epoch.length);
            epoch.lastUpdate = block.timestamp;
            epoch.number++;

            if(address(distributor) != address(0)) {
                rewardAmount = distributor.distributeAmount();
            }
            uint256 balance = BTCH.balanceOf(address(this));
            uint256 staked = sBTCH.circulatingSupply();
            
            epoch.distribute = 0;
            if(balance > staked) {
                balance = balance.sub(staked);
                epoch.distribute = balance < rewardAmount ? balance: rewardAmount;
            }
        }
        
        if(address(bondDepository) != address(0)) {
            bondDepository.rebase(epoch.number);
        }
    }

    function index() public view returns (uint256) 
    {
        return sBTCH.index();
    }

    function secondsToNextEpoch() external view returns (uint256) 
    {
        return epoch.end.sub(block.timestamp);
    }
    
    function epochNumber() external view returns (uint256 curEpoch, uint256 curEpochEndTime) {
        curEpoch = epoch.number;
        curEpochEndTime = epoch.end;
    }
    
    function epochLength() external view returns (uint256 _epochLength) {
        _epochLength = epoch.length;
    }

    function setDistributor(address _distributor) external onlyGovernorPolicy 
    {
        distributor = IDistributor(_distributor);
        emit DistributorSet(_distributor);
    }
    
    function setBondDepository(address _bondDepository) external onlyGovernorPolicy 
    {
        bondDepository = IBondDepository(_bondDepository);
        emit BondDepositorySet(_bondDepository);
    }
    
    function enableRebase(uint256 _firstEpochTime) external onlyGovernorPolicy     
    {
        require(!rebaseEnabled, "AlreadyEnabled");
        require(_firstEpochTime > block.timestamp, "NeedTimeInFuture");
        
        epoch.end = _firstEpochTime;
        rebaseEnabled = true;
    }
}
