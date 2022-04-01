// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.4;

import "../types/FrontEndRewarder.sol";

import "../lib/SafeERC20.sol";
import "../lib/SafeMath.sol";

import "../interfaces/IPriceHelper.sol";
import "../interfaces/IsBTCH.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/INoteKeeper.sol";
import "../interfaces/IGenesis.sol";

abstract contract NoteKeeper is INoteKeeper, FrontEndRewarder {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    uint public constant INDEX_GENESIS_0 = 0;
    uint public constant INDEX_GENESIS_1 = 1;
    uint public constant INDEX_GENESIS_BOND = 2;
    uint public constant INDEX_GENESIS_REWARD = 3;
    
    bool public triggerPriceUpdate;
    bool public genesisUpdatingEnded;
    
    uint public genesisPayout;
    uint public genesisBondPayout;
    
    uint public epochLength;
    uint public genesisEpochNumber;
    uint public genesisEpochEndTime;
    uint public genesisLength;
    uint public genesisBondLength;
    
    uint public genesisBondCreated;
    uint public genesisLastEpochNumber;
    
    uint[21] public bondingAmounts;     // used as ring for bonding amounts with 21 Epochs for bondValueAmount as USDC.
    uint     public bondingIndex;       // index to ring.
    uint     public bondingEpochNumber; // first Epoch with index.
    
    uint[4] public totalGenesis;        //INDEX_GENESIS_1/INDEX_GENESIS_BOND are gons of sBTCH with expiry and adjusted with rebase.
    uint[4] public totalGenesisClaimed; //gons of sBTCH.
    mapping(address => uint) public userGenesisClaimedEpoch; 
    mapping(address => uint[]) public userGenesisClaimedAmount;
    
    mapping(address => Note[]) public notes; // user bond deposit data

    IsBTCH public immutable sBTCH;
    IStaking public immutable staking;
    ITreasury public treasury;
    IGenesis public genesis;
    IPriceHelper public priceHelper;
    
    address public genesisReward;
    address public rebalancer;
    
    modifier onlyStakingContract() {
        require(msg.sender == address(staking), "NoStakingContract");
        _;
    }
    
    modifier onlyGenesisReward() {
        require(msg.sender == genesisReward, "UNAUTHORIZED");
        _;
    }
    
    modifier onlyRebalancer() {
        require(msg.sender == rebalancer, "UNAUTHORIZED");
        _;
    }

    constructor(IHodlAuthority _authority, IERC20 _btch, IsBTCH _sBTCH, IStaking _staking, ITreasury _treasury, IGenesis _genesis, IPriceHelper _priceHelper) 
        FrontEndRewarder(_authority, _btch) 
    {
        sBTCH = _sBTCH;
        staking = _staking;
        treasury = _treasury;
        genesis = _genesis;
        priceHelper = _priceHelper;
    }

    function updateParameters(ITreasury _treasury, IGenesis _genesis, IPriceHelper _priceHelper, address _genesisReward, address _rebalancer, bool _triggerPriceUpdate) 
        external override onlyGovernorPolicy 
    {
        treasury = _treasury;
        genesis = _genesis;
        priceHelper = _priceHelper;
        genesisReward = _genesisReward;
        rebalancer = _rebalancer;
        triggerPriceUpdate = _triggerPriceUpdate;
    }

    //adds a new Note for user bonding.
    function addNoteForBond(address _user, uint256 _payout, uint48 _expiry, uint48 _marketID, address _referral) 
        internal returns (uint256 index_) 
    {
        require(genesisPayout > 0, "NoGenesis");
        
        index_ = notes[_user].length;
        notes[_user].push(
            Note({
                payout: sBTCH.gonsForBalance(_payout),
                payoutRemain: sBTCH.gonsForBalance(_payout),
                created: uint48(block.timestamp),
                matured: _expiry,
                redeemed: 0,
                marketID: _marketID
            })
        );
        
        (uint256 toGen, uint256 toStaking, uint256 toDev, uint256 toRef) = _giveRewards(_payout, _referral);
        totalGenesis[INDEX_GENESIS_REWARD] += sBTCH.gonsForBalance(toGen);

        treasury.mint(address(this), _payout + toGen + toDev + toRef);
        if(toStaking > 0)
            treasury.mint(address(staking), toStaking);
        staking.stake(address(this), _payout + toGen);
        if(toDev > 0)
            staking.stake(authority.guardian(), toDev);
    }
    
    function addNoteForGenesis(uint256 _payout, uint256 _vestingLength, address _referral, uint256 _type) 
        internal 
    {
        require(_type <= INDEX_GENESIS_BOND, "InvalidType");
        
        (uint256 toGen, uint256 toStaking, uint256 toDev, uint256 toRef) = _giveRewards(_payout, _referral);
        if(_type == INDEX_GENESIS_0) {
            totalGenesis[_type] += sBTCH.gonsForBalance(_payout);
            toGen = 0;
            toStaking = 0;
            toDev = 0;
        }
        else if(_type == INDEX_GENESIS_1) {
            genesisLength = _vestingLength;
            toGen = 0;
            toStaking = 0;
            toDev = 0;
        }
        else if(_type == INDEX_GENESIS_BOND) {
            genesisBondCreated = block.timestamp;
            genesisBondLength = _vestingLength;
        }
        
        totalGenesis[INDEX_GENESIS_REWARD] += sBTCH.gonsForBalance(toGen);
        treasury.mint(address(this), _payout + toGen + toDev + toRef);
        if(toStaking > 0)
            treasury.mint(address(staking), toStaking);
        
        if(toDev > 0)
            staking.stake(authority.guardian(), toDev);
            
        if(_type == INDEX_GENESIS_0) {
            staking.stake(address(this), _payout);
        }
        else if(_type == INDEX_GENESIS_BOND) {
            staking.stake(address(this), toGen);
        }
    }
    
    function addNoteForRebalance(uint256 adjustType, uint256 _payoutToStaking, uint256 _payoutToInvoker, address _invoker, address _referral)
        internal 
    {
        require(genesisPayout > 0, "NoGenesis");
        
        (uint256 toGen, uint256 toStaking, uint256 toDev, uint256 toRef) = _giveRewardsForStakingReward(_payoutToStaking, _referral);

        totalGenesis[INDEX_GENESIS_REWARD] += sBTCH.gonsForBalance(toGen);

        // Attention. BTCH should been transferred from Rebalancer.
        if(adjustType == 1) {
            IERC20(btch).safeTransferFrom(rebalancer, address(this), toGen + toStaking + toDev + toRef);
            if(toStaking > 0)
                IERC20(btch).safeTransfer(address(staking), toStaking);
        }
        else if(adjustType == 2) {
            treasury.mint(address(this), toGen + toDev + toRef);
            if(toStaking > 0)
                treasury.mint(address(staking), toStaking);
            if(_payoutToInvoker > 0)
                treasury.mint(_invoker, _payoutToInvoker);
        }
        
        if(toGen > 0)
            staking.stake(address(this), toGen);
        if(toDev > 0)
            staking.stake(authority.guardian(), toDev);
    }

    function redeem(address _user, uint256[] memory _indexes) 
        public override returns (uint256 payout_) 
    {
        staking.rebase();
        
        uint48 time = uint48(block.timestamp);
        for (uint256 i = 0; i < _indexes.length; i++) {
            uint256 pay = pendingFor(_user, _indexes[i]);

            if (pay > 0) {
                notes[_user][_indexes[i]].payoutRemain -= pay;
                notes[_user][_indexes[i]].redeemed = time;
                payout_ += pay;
            }
        }
        
        payout_ = sBTCH.balanceForGons(payout_);
        staking.unstake(_user, payout_);
    }

    //redeem all redeemable markets for user
    function redeemAll(address _user)
        external override returns (uint256) 
    {
        return redeem(_user, indexesFor(_user));
    }
    
    //redeem genesis notes by genesis participants.
    function redeemGenesis() 
        external override returns (uint256 payout_)
    {
        staking.rebase();
        
        address user = msg.sender;
        (uint256 genesisAmount, uint256 bondAmount, uint256 userGenesisAmount, uint256 userBondAmount) = userGenesisAmountInfo(user);
        require(userGenesisAmount > 0, "NoGenesis");
        
        if(userGenesisClaimedEpoch[user] == 0) {
            userGenesisClaimedEpoch[user] = genesisLastEpochNumber;
            for(uint i=0; i<4; i++)
                userGenesisClaimedAmount[user].push(0);
        }
        
        for(uint256 i=0; i<=INDEX_GENESIS_REWARD; i++) {
            uint256 curPayout = (i != INDEX_GENESIS_BOND) ? 
                pendingForGenesis0123(genesisAmount, userGenesisAmount, i, user)
                : pendingForGenesis0123(bondAmount, userBondAmount, i, user);
            if(curPayout > 0) {
                userGenesisClaimedAmount[user][i] += curPayout;
                totalGenesisClaimed[i] += curPayout;
                payout_ += curPayout;
            }
        }
        
        if(payout_ > 0) {
            payout_ = sBTCH.balanceForGons(payout_);
            staking.unstake(user, payout_);
        }
    }
    
    function pendingGenesis(address _user)
        public view override returns (uint256 _payout)
    {
        (uint256 genesisAmount, uint256 bondAmount, uint256 userGenesisAmount, uint256 userBondAmount) = userGenesisAmountInfo(_user);
        
        _payout += pendingForGenesis0123(genesisAmount, userGenesisAmount, INDEX_GENESIS_0, _user);
        _payout += pendingForGenesis0123(genesisAmount, userGenesisAmount, INDEX_GENESIS_1, _user);
        _payout += pendingForGenesis0123(bondAmount, userBondAmount, INDEX_GENESIS_BOND, _user);
        _payout += pendingForGenesis0123(genesisAmount, userGenesisAmount, INDEX_GENESIS_REWARD, _user);
        
        _payout = sBTCH.balanceForGons(_payout);
    }
    
    function pendingForGenesis0123(uint256 _totalAmount, uint256 _userAmount, uint256 _type, address _user)
        public view override returns (uint256 payout_) 
    {
        //Need to div first to avoid overflow.
        uint userGenesisTotal = totalGenesis[_type].div(_totalAmount).mul(_userAmount);
        payout_ = (userGenesisClaimedEpoch[_user] == 0) ? userGenesisTotal : userGenesisTotal - userGenesisClaimedAmount[_user][_type];
    }

    //all pending notes for user
    function indexesFor(address _user) 
        public view override returns (uint256[] memory) 
    {
        Note[] memory info = notes[_user];

        uint256 length;
        for (uint256 i = 0; i < info.length; i++) {
            if (info[i].payoutRemain > 0) length++;
        }

        uint256[] memory indexes = new uint256[](length);
        uint256 position;

        for (uint256 i = 0; i < info.length; i++) {
            if (info[i].payoutRemain > 0) {
                indexes[position] = i;
                position++;
            }
        }

        return indexes;
    }

    //calculate amount available to claim for a single note
    function pendingFor(address _user, uint256 _index) 
        public view override returns (uint256 payout_) 
    {
        Note memory note = notes[_user][_index];
        if(note.payoutRemain == 0 || note.matured == note.created) {
            payout_ = note.payoutRemain;
            return payout_;
        }
        
        (uint256 firstEpoch, uint256 lastEpoch, uint256 nextEpoch) = getEpochRange(note.created, note.matured, note.redeemed);
        (uint256 curEpoch,) = staking.epochNumber();
        
        if(curEpoch > lastEpoch) {
            payout_ = note.payoutRemain;
            return payout_;
        }
        
        if(nextEpoch >= curEpoch) {
            payout_ = 0;
            return payout_;
        }
        
        payout_ = note.payout.mul(curEpoch.sub(nextEpoch));
        payout_ = payout_.div(lastEpoch.sub(firstEpoch).add(1));
        if(payout_ > note.payoutRemain)
            payout_ = note.payoutRemain;
            
        return payout_;
    }
    
    function userGenesisAmountInfo(address user) 
        internal view returns (uint256 genesisAmount, uint256 bondAmount, uint256 userGenesisAmount, uint256 userBondAmount) 
    {
        (genesisAmount, bondAmount,,) = genesis.getGenesisInfo();
        genesisAmount = genesisAmount - bondAmount;
        
        uint256 bondRate;
        uint256 bondRateLevel;
        (userGenesisAmount, bondRate, bondRateLevel) = genesis.getUserGenesisInfo(user);
        
        if(userGenesisAmount > 0) {
            userBondAmount = userGenesisAmount * bondRate / bondRateLevel;
            userGenesisAmount = userGenesisAmount - userBondAmount;
        }
    }
    
    function getEpochRange(uint256 created, uint256 expiry, uint256 redeemed) 
        public view returns (uint256 firstEpoch, uint256 lastEpoch, uint256 nextEpoch) 
    {
        firstEpoch = (created < genesisEpochEndTime) ? genesisEpochNumber : genesisEpochNumber + 1 + created.sub(genesisEpochEndTime).div(epochLength);
        lastEpoch = (expiry < genesisEpochEndTime) ? genesisEpochNumber : genesisEpochNumber + expiry.sub(genesisEpochEndTime).div(epochLength);
        if(lastEpoch < firstEpoch)
            lastEpoch = firstEpoch;
        nextEpoch = (redeemed < genesisEpochEndTime) ? firstEpoch : genesisEpochNumber + 1 + redeemed.sub(genesisEpochEndTime).div(epochLength);
    }
}
