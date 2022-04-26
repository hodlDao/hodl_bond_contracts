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
import "./interfaces/IRebalancer.sol";

contract HodlBondDepository is IBondDepository, NoteKeeper {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event CreateMarket(uint256 indexed id, address indexed baseToken, address indexed quoteToken, uint256 controlVariable);
    event Bond(uint256 indexed id, uint256 amount, uint256 price);
    event BondInfoUpdated(uint256 indexed id, uint256 baseVariable, uint256 controlVariable);

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
        IPriceHelper _priceHelper,
        address _wbtc
    ) NoteKeeper(_authority, _btch, _sBTCH, _staking, _treasury, _genesis, _priceHelper) {
        _btch.approve(address(_staking), type(uint256).max);
        IERC20(address(_sBTCH)).approve(address(_staking), type(uint256).max);
        wbtc = _wbtc;
    }
    
    //creates a new market type
    function create(IERC20  _quoteToken, uint256 _baseVariable, uint256 _controlVariable, uint256 _vestingTerm, bool _isActive) 
        external override onlyGovernorPolicy returns (uint256 id_) 
    {

        uint256 decimals = IERC20Metadata(address(_quoteToken)).decimals();

        id_ = markets.length;

        markets.push(
            Market({
                quoteToken: _quoteToken,
                sold: 0,
                purchased: 0,
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
                quoteDecimals: decimals
            })
        );

        emit CreateMarket(id_, address(btch), address(_quoteToken), _controlVariable);
    }
    
    function enableMarket(uint256 _id, bool _enableMarket, address _swapHelper) 
        external override onlyGovernorPolicy 
    {
        require(address(markets[_id].quoteToken) != address(0), "NoMarket");
        markets[_id].isActive = _enableMarket;
        swapHelper = _swapHelper;
    }
    
    function updateBondInfo(uint256 _id, uint256 _baseVariable, uint256 _controlVariable) 
        external onlyGovernorPolicy 
    {
        require(address(markets[_id].quoteToken) != address(0), "NoMarket");
        require(_baseVariable <= 1e4 && _baseVariable >= 1000, "InvalidRange1");
        require(_controlVariable <= 10000e4 && _controlVariable >= 1000, "InvalidRange2");
        terms[_id].baseVariable = _baseVariable;
        terms[_id].controlVariable = _controlVariable;
        emit BondInfoUpdated(_id, _baseVariable, _controlVariable);
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
        bondingIndex = (bondingIndex+1) % EPOCH_SIZE;
        
        bondingEpochNumber = curEpoch;
    }
    
    //should be used after rebase.
    function adjustBondingAmounts(uint256 bondValueAmount, uint256 epochCount) 
        internal 
    {
        require(epochCount <= EPOCH_SIZE, "Mismatch2");
        
        uint bondValueAmountPerEpoch = (epochCount == 0) ? 0 : bondValueAmount.div(epochCount);
        for(uint256 i=0; i<epochCount; i++) {
            bondingAmounts[(bondingIndex+i)%EPOCH_SIZE] += bondValueAmountPerEpoch;
        }
    }

    //bondValueAmount is incoming bondValueAmount.
    function getBondingAmount(uint256 bondValueAmount) 
        internal view returns (uint256 curBondingAmount)
    {
        curBondingAmount = bondValueAmount;

        for(uint256 slot = 0; slot < EPOCH_SIZE; slot++) 
            curBondingAmount += bondingAmounts[slot];
    }
    
    //deposit quote token to bond from a specified market
    //Here _maxPrice is based on BTCH/USDC.
    function deposit(uint256 _id, uint256 _amount, uint256 _maxPrice, address _user, address _referral)
        external override returns (uint256 payout_, uint256 epochCount_, uint256 index_)
    {
        Market storage market = markets[_id];
        require(market.isActive, "MarketNotActive");

        staking.rebase();
        
        uint256 price;
        (uint256 bondValueAmount, uint256 btcAmount) = bondValue(_id, _amount);
        require(_amount > 0 && btcAmount > 0, "NoAmount1");
        
        (payout_, price) = payoutFor(_id, bondValueAmount);
        require(price <= _maxPrice, "MaxPrice");

        market.purchased += _amount;
        market.sold += payout_;

        emit Bond(_id, _amount, price);

        (index_, epochCount_) = addNoteForBond(_user, payout_, terms[_id].vestingTerm, uint48(_id), _referral);
        adjustBondingAmounts(bondValueAmount, epochCount_);
        
        if(address(market.quoteToken) != wbtc) {
            IERC20(market.quoteToken).safeTransferFrom(msg.sender, swapHelper, _amount);
            uint oldWBTC = IERC20(wbtc).balanceOf(address(this));
            ISwapHelper(swapHelper).swapExactTokensForTokens(address(market.quoteToken), wbtc, _amount, btcAmount);
            _amount = IERC20(wbtc).balanceOf(address(this));
            require(_amount >= oldWBTC + btcAmount, "NoAmount2");
            IERC20(wbtc).safeTransfer(address(treasury), _amount);
        }
        else {
            market.quoteToken.safeTransferFrom(msg.sender, address(treasury), _amount);
        }
        
        if(triggerPriceUpdate)
            IPriceHelper(priceHelper).update();
    }
    
    //deposit quote token as usdc for genesis
    function depositForGenesis(uint256 _id, uint256 _amount, uint256 _genesisLength, uint256 _bondLength, address _referral)
        external override onlyGenesisReward
    {
        require(_id == 0 && _amount > 0 && genesisPayout == 0, "NoCondition");
        require(address(markets[_id].quoteToken) != address(0), "NoMarket");
        Market storage market = markets[_id];
        
        staking.rebase();
        
        (uint256 genesisAmount, uint256 bondAmount, uint256 priceGenesis, uint256 priceBond) = IGenesis(genesis).getGenesisInfo();
        genesisAmount = genesisAmount.sub(bondAmount);
        
        genesisEpochNumber = bondingEpochNumber;
        market.purchased += _amount;
        
        //INDEX_GENESIS_0 + INDEX_GENESIS_1
        genesisPayout = payoutWithPrice(genesisAmount, priceGenesis);
        market.sold += genesisPayout;
        addNoteForGenesis(genesisPayout / 10, 0, _referral, INDEX_GENESIS_0);
        addNoteForGenesis(genesisPayout - genesisPayout / 10, _genesisLength, _referral, INDEX_GENESIS_1);
        
        //INDEX_GENESIS_BOND
        genesisBondPayout = payoutWithPrice(bondAmount, priceBond);
        market.sold += genesisBondPayout;
        addNoteForGenesis(genesisBondPayout, _bondLength, _referral, INDEX_GENESIS_BOND);
        adjustBondingAmounts(bondAmount, _bondLength/epochLength);

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
    
    //used with usdc quote token for Genesis.
    function payoutWithPrice(uint256 _amountUSDC, uint256 _price) 
        public pure override returns (uint256 _payout) 
    {
        _payout = (_amountUSDC * 1e9) / _price;
    }
    
    //get usdc bond value of quoteToken as WBTC asset.
    function bondValue(uint256 _id, uint256 _amount)
        public view override returns (uint256 amountValue, uint256 btcAmount) 
    {
        address quoteToken = address(markets[_id].quoteToken);
        btcAmount = _amount;
        if(quoteToken != wbtc) {
            uint[] memory amountsOut = ISwapHelper(swapHelper).getAmountsOut(quoteToken, wbtc, _amount);
            btcAmount = amountsOut[amountsOut.length-1];
        }
        
        amountValue = IRebalancer(rebalancer).getWBTCAmount2USDCValue(btcAmount);
    }
    
    //1e9 = BTCH decimals (9)
    function payoutFor(uint256 _id, uint256 _amountValue) 
        public view override returns (uint256 _payout, uint256 _payoutPrice) 
    {
        _payoutPrice = payoutPrice(_id, _amountValue);
        _payout = (_amountValue * 1e9) / _payoutPrice;
    }
    
    //used with usdc _amountValue against quoteToken.
    function payoutPrice(uint256 _id, uint256 _amountValue)
        public view override returns (uint256 _payoutPrice) 
    {
        _payoutPrice = IPriceHelper(priceHelper).getBTCUSDC365()/10000;
        uint256 discount = bondDiscount(_id, _amountValue);
        _payoutPrice = _payoutPrice * discount / 10000;
    }
    
    //used with usdc _amountValue against quoteToken.
    function bondDiscount(uint256 _id, uint256 _amountValue) 
        public view override returns (uint256 discount) 
    {
        uint256 bondingValueAmount = bondingValue(_amountValue);
        uint256 controlVariable = currentControlVariable(_id);
        discount = bondingValueAmount*controlVariable/treasury.hodlValue()+terms[_id].baseVariable;
    }
    
    //used with usdc _amountValue against quoteToken.
    function bondingValue(uint256 _amountValue) 
        public view override returns (uint256 bondingValueAmount) 
    {
        bondingValueAmount = getBondingAmount(_amountValue/2);
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
        uint256 marketsLength = markets.length;
        for (uint256 i = 0; i < marketsLength; i++) {
            if (isLive(i)) num++;
        }

        uint256[] memory ids = new uint256[](num);
        num = 0;
        for (uint256 i = 0; i < marketsLength; i++) {
            if (isLive(i)) {
                ids[num] = i;
                num++;
            }
        }
        return ids;
    }
}
