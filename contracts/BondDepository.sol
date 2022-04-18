// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.4;

import "./types/NoteKeeper.sol";

import "./lib/SafeERC20.sol";
import "./lib/SafeMath.sol";

import "./interfaces/IGenesis.sol";
import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IBondDepository.sol";
import "./interfaces/IBondCalculator.sol";
import "./interfaces/ISwapHelper.sol";

contract HodlBondDepository is IBondDepository, NoteKeeper {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event CreateMarket(uint256 indexed id, address indexed baseToken, address indexed quoteToken, uint256 controlVariable);
    event Bond(uint256 indexed id, uint256 amount, uint256 price);

    Market[] public markets;    // persistent market data
    Terms[] public terms;       // deposit construction data
    Metadata[] public metadata; // extraneous market data
    
    address public wbtc;
    address public swapHelper;

    constructor(
        IHodlAuthority _authority, 
        IERC20 _btch, 
        IsBTCH _sBTCH, 
        IStaking _staking, 
        ITreasury _treasury, 
        IGenesis _genesis, 
        IPriceHelper _priceHelper
    ) NoteKeeper(_authority, _btch, _sBTCH, _staking, _treasury, _genesis, _priceHelper) {
        _btch.approve(address(_staking), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        IERC20(address(_sBTCH)).approve(address(_staking), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }
    
    //creates a new market type
    function create(IERC20  _quoteToken, address _bondCalculator, uint256 _baseVariable, uint256 _controlVariable, uint256 _vestingTerm, bool _isActive) 
        external override onlyGovernorPolicy returns (uint256 id_) 
    {

        uint256 decimals = IERC20Metadata(address(_quoteToken)).decimals();

        id_ = markets.length;

        markets.push(
            Market({
                quoteToken: _quoteToken,
                sold: 0,
                purchased: 0,
                enableQuote2WBTC: true,
                isActive: _isActive
            })
        );

        terms.push(
            Terms({
                baseVariable: _baseVariable,
                controlVariable: _controlVariable,
                vestingTerm: _vestingTerm
            })
        );

        metadata.push(
            Metadata({
                quoteDecimals: decimals,
                bondCalculator: _bondCalculator
            })
        );

        emit CreateMarket(id_, address(btch), address(_quoteToken), _controlVariable);
    }
    
    function enableMarketAnd2BTC(uint256 _id, bool _enableMarket, bool _enableBTC, address _swapHelper, address _wbtc) 
        external override onlyGovernorPolicy 
    {
        require(address(markets[_id].quoteToken) != address(0), "NoMarket");
        markets[_id].isActive = _enableMarket;
        markets[_id].enableQuote2WBTC = _enableBTC;
        swapHelper = _swapHelper;
        wbtc = _wbtc;
    }
    
    function updateBondInfo(uint256 _id, uint256 _baseVariable, uint256 _controlVariable) 
        external onlyGovernorPolicy 
    {
        require(address(markets[_id].quoteToken) != address(0), "NoMarket");
        terms[_id].baseVariable = _baseVariable;
        terms[_id].controlVariable = _controlVariable;
    }
    
    function updateCalculator(uint256 _id, address _bondCalculator) 
        external override onlyGovernorPolicy 
    {
        require(address(markets[_id].quoteToken) != address(0), "NoMarket");
        metadata[_id].bondCalculator = _bondCalculator;
    }
    
    function rebase(uint256 curEpoch) 
        external override onlyStakingContract
    {
        if(bondingEpochNumber == curEpoch)
            return;
            
        if(bondingEpochNumber == 0) {
            bondingEpochNumber = curEpoch;
            genesisEpochNumber = curEpoch;
            bondingIndex = 0;
            epochLength = staking.epochLength();
            return;
        }
        
        require(bondingEpochNumber+1 == curEpoch, "EpochMismatch");
        
        if(!genesisUpdatingEnded && totalGenesis[INDEX_GENESIS_0] > 0) {
            uint256 amountPerEpoch;
            uint256 deltaGons;
            uint256 payout;
            
            //For INDEX_GENESIS_1
            amountPerEpoch = genesisPayout - genesisPayout / 10;
            amountPerEpoch = amountPerEpoch.mul(epochLength).div(genesisLength);
            if(bondingEpochNumber >= genesisEpochNumber+genesisLength.div(epochLength)) {
                amountPerEpoch = 0;
                genesisUpdatingEnded = true;
            }
                
            if(amountPerEpoch > 0) {
                deltaGons = sBTCH.gonsForBalancePerEpoch(amountPerEpoch, bondingEpochNumber);
                totalGenesis[INDEX_GENESIS_1] += deltaGons;
                payout += sBTCH.balanceForGons(deltaGons);
            }
            
            //For INDEX_GENESIS_BOND
            if(bondingEpochNumber < genesisEpochNumber+genesisBondLength.div(epochLength)) {
                amountPerEpoch = genesisBondPayout.mul(epochLength).div(genesisBondLength);
                deltaGons = sBTCH.gonsForBalancePerEpoch(amountPerEpoch, bondingEpochNumber);
                totalGenesis[INDEX_GENESIS_BOND] += deltaGons;
                payout += sBTCH.balanceForGons(deltaGons);
            }
            
            if(payout > 0) {
                treasury.mint(address(this), payout);
                staking.stake(address(this), payout);
            }
        }
        
        bondingAmounts[bondingIndex] = 0;
        bondingIndex = (bondingIndex+1) % 21;
        
        bondingEpochNumber = curEpoch;
    }
    
    //should be used after rebase.
    function adjustBondingAmounts(uint256 bondValueAmount, uint256 epochCount) 
        internal 
    {
        require(epochCount <= 21, "Mismatch2");
        
        uint bondValueAmountPerEpoch = (epochCount == 0) ? 0 : bondValueAmount.div(epochCount);
        for(uint256 i=0; i<epochCount; i++) {
            bondingAmounts[(bondingIndex+i)%21] += bondValueAmountPerEpoch;
        }
    }

    //bondValueAmount is incoming bondValueAmount.
    function getBondingAmount(uint256 bondValueAmount) 
        internal view returns (uint256 curBondingAmount)
    {
        curBondingAmount = bondValueAmount;

        for(uint256 slot = 0; slot < 21; slot++) 
            curBondingAmount += bondingAmounts[slot];
    }
    
    //deposit quote tokens to bond from a specified market
    //Here _maxPrice is based on BTCH/USDC.
    function deposit(uint256 _id, uint256 _amount, uint256 _maxPrice, address _user, address _referral)
        external override returns (uint256 payout_, uint256 epochCount_, uint256 index_)
    {
        Market storage market = markets[_id];
        Terms storage term = terms[_id];
        require(market.isActive, "MarketNotActive");

        staking.rebase();
        
        uint256 price;
        uint bondValueAmount;
        (payout_, price, bondValueAmount) = payoutFor(_id, _amount);
        require(price <= _maxPrice, "MaxPrice");

        market.purchased += _amount;
        market.sold += payout_;

        emit Bond(_id, _amount, price);

        (index_, epochCount_) = addNoteForBond(_user, payout_, term.vestingTerm, uint48(_id), _referral);
        adjustBondingAmounts(bondValueAmount, epochCount_);
        
        if(market.enableQuote2WBTC && address(market.quoteToken) != wbtc) {
            IERC20(market.quoteToken).safeTransferFrom(msg.sender, swapHelper, _amount);
            uint oldWBTC = IERC20(wbtc).balanceOf(address(this));
            ISwapHelper(swapHelper).swapExactTokensForTokens(address(market.quoteToken), wbtc, _amount, 1);
            _amount = IERC20(wbtc).balanceOf(address(this));
            require(_amount > oldWBTC, "NoAmount");
            IERC20(wbtc).safeTransfer(address(treasury), _amount);
        }
        else {
            market.quoteToken.safeTransferFrom(msg.sender, address(treasury), _amount);
        }
        
        if(triggerPriceUpdate)
            IPriceHelper(priceHelper).update();
    }
    
    //deposit quote tokens as genesis from a specified market
    function depositForGenesis(uint256 _id, uint256 _amount, uint256 _genesisLength, uint256 _bondLength, address _referral)
        external override onlyGenesisReward
    {
        require(_id == 0 && _amount > 0 && genesisPayout == 0, "NoCondition");
        require(address(markets[_id].quoteToken) != address(0), "NoMarket");
        Market storage market = markets[_id];
        
        staking.rebase();
        
        //Note genesisAmount is same as bondValue for USDC.
        (uint256 genesisAmount, uint256 bondAmount, uint256 priceGenesis, uint256 priceBond) = IGenesis(genesis).getGenesisInfo();
        genesisAmount = genesisAmount.sub(bondAmount);
        
        genesisEpochNumber = bondingEpochNumber;
        market.purchased += _amount;
        
        //INDEX_GENESIS_0 + INDEX_GENESIS_1
        (genesisPayout,) = payoutWithPrice(_id, genesisAmount, priceGenesis);
        market.sold += genesisPayout;
        addNoteForGenesis(genesisPayout / 10, 0, _referral, INDEX_GENESIS_0);
        addNoteForGenesis(genesisPayout - genesisPayout / 10, _genesisLength, _referral, INDEX_GENESIS_1);
        
        //INDEX_GENESIS_BOND
        //reuse genesisAmount as bondValueAmount
        (genesisBondPayout, genesisAmount) = payoutWithPrice(_id, bondAmount, priceBond);
        market.sold += genesisBondPayout;
        addNoteForGenesis(genesisBondPayout, _bondLength, _referral, INDEX_GENESIS_BOND);
        adjustBondingAmounts(genesisAmount, _bondLength/epochLength);

        // transfer payment to treasury
        market.quoteToken.safeTransferFrom(msg.sender, address(treasury), _amount);
    }
    
    //deposit reward as rebalance.
    function depositForRebalance(uint256 adjustType, uint256 stakingReward, uint256 invokerReward, address invoker, address _referral)
        external override onlyRebalancer
    {
        staking.rebase();
        
        addNoteForRebalance(adjustType, stakingReward, invokerReward, invoker, _referral);
    }
    
    //1e9 = BTCH decimals (9)
    function payoutFor(uint256 _id, uint256 _amount) 
        public view override returns (uint256 _payout, uint256 _payoutPrice, uint256 _bondValueAmount) 
    {
        (_payoutPrice, _bondValueAmount) = payoutPrice(_id, _amount);
        _payout = (_bondValueAmount * 1e9) / _payoutPrice;
    }
    
    function payoutWithPrice(uint256 _id, uint256 _amount, uint256 _price) 
        public view override returns (uint256 _payout, uint256 _bondValueAmount) 
    {
        _bondValueAmount = bondValue(_id, _amount);
        _payout = (_bondValueAmount * 1e9) / _price;
    }
    
    function payoutPrice(uint256 _id, uint256 _amount) 
        public view override returns (uint256 _payoutPrice, uint256 _bondValueAmount) 
    {
        _payoutPrice = IPriceHelper(priceHelper).getBTCUSDC365()/10000;
        (uint256 discount, uint256 bondValueAmount) = bondDiscount(_id, _amount);
        _bondValueAmount = bondValueAmount;
        _payoutPrice = _payoutPrice * discount / 10000;
    }
    
    function bondDiscount(uint256 _id, uint256 _amount) 
        public view override returns (uint256 discount, uint256 bondValueAmount) 
    {
        //reuse discount as bondingAmount.
        (discount, bondValueAmount) = bondingValue(_id, _amount);
        uint256 controlVariable = currentControlVariable(_id);
        discount = discount*controlVariable/treasury.hodlValue()+terms[_id].baseVariable;
    }
    
    function bondValue(uint256 _id, uint256 _amount) 
        public view override returns (uint256 amount) 
    {
        if(_id == 0) {
            amount  = _amount;
            return amount;
        }
        
        require(metadata[_id].bondCalculator != address(0), "NoCalculator");
        amount = IBondCalculator(metadata[_id].bondCalculator).valuation(address(markets[_id].quoteToken), metadata[_id].quoteDecimals, _amount);
    }
    
    function bondingValue(uint256 _id, uint256 _amount) 
        public view override returns (uint256 bondingAmount, uint256 bondValueAmount) 
    {
        bondValueAmount = bondValue(_id, _amount);
        bondingAmount = getBondingAmount(bondValueAmount/2);
    }
 
    function currentControlVariable(uint256 _id) 
        public view override returns (uint256) 
    {
        return terms[_id].controlVariable;
    }
    
    function isLive(uint256 _id) 
        public view returns (bool) 
    {
        return markets[_id].isActive;
    }

    function liveMarkets() 
        public view override returns (uint256[] memory) 
    {
        uint256 num;
        for (uint256 i = 0; i < markets.length; i++) {
            if (isLive(i)) num++;
        }

        uint256[] memory ids = new uint256[](num);
        uint256 nonce;
        for (uint256 i = 0; i < markets.length; i++) {
            if (isLive(i)) {
                ids[nonce] = i;
                nonce++;
            }
        }
        return ids;
    }
}
