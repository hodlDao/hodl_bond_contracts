// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

import "./IERC20.sol";

interface IBondDepository {
    // Info about each type of market
    struct Market {
        IERC20  quoteToken; // token to accept as payment
        uint256 sold;       // base tokens out
        uint256 purchased;  // quote tokens in
        bool    enableQuote2WBTC;
        bool    isActive;   // active for bond
    }

    // Info for creating new markets
    struct Terms {
        uint256 baseVariable;    // base variable for price, 1e4
        uint256 controlVariable; // scaling variable for price, 1e4
        uint256 vestingTerm;     // release time period.
    }

    // Additional info about market.
    struct Metadata {
        uint256 quoteDecimals;   // decimals of quote token
        address bondCalculator;  // bond value calculator
    }
    
    function create(
        IERC20  _quoteToken,
        address _bondCalculator,
        uint256 _baseVariable,
        uint256 _controlVariable,
        uint256 _vestingTerm,
        bool    _isActive
    ) external returns (uint256 id_);
    
    function enableMarketAnd2BTC(uint256 _id, bool _enableMarket, bool _enableBTC, address _swapHelper, address _wbtc) external;
    function updateCalculator(uint256 _id, address _bondCalculator) external;
    
    function deposit(
        uint256 _id,
        uint256 _amount,
        uint256 _maxPrice,
        address _user,
        address _referral
    )
        external
        returns (
            uint256 payout_,
            uint256 expiry_,
            uint256 index_
        );
    
    function depositForGenesis(
        uint256 _id,
        uint256 _amount,
        uint256 _genesisLength,
        uint256 _bondLength,
        address _referral
    )
        external;

    function depositForRebalance(
        uint256 adjustType,
        uint256 stakingReward,
        uint256 invokerReward,
        address invoker, 
        address _referral
    )
        external;
        
    function rebase(uint256 curEpoch) external;    
    function payoutFor(uint256 _id, uint256 _amount) external view returns (uint256 _payout, uint256 _payoutPrice, uint256 _bondValueAmount);
    function payoutWithPrice(uint256 _id, uint256 _amount, uint256 _price) external view returns (uint256 _payout, uint256 _bondValueAmount);
    function payoutPrice(uint256 _id, uint256 _amount) external view returns (uint256 _payoutPrice, uint256 _bondValueAmount);
    function bondDiscount(uint256 _id, uint256 _amount) external view returns (uint256 discount, uint256 bondValueAmount);
    function bondValue(uint256 _id, uint256 _amount) external view returns (uint256 amount);
    function bondingValue(uint256 _id, uint256 _amount) external view returns (uint256 bondingAmount, uint256 bondValueAmount);
    function currentControlVariable(uint256 _id) external view returns (uint256);
    function liveMarkets() external view returns (uint256[] memory);
}
