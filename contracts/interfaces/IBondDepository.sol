// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

import "./IERC20.sol";

interface IBondDepository {
    // Info about each type of market
    struct Market {
        IERC20  quoteToken; // token to accept as payment
        uint256 sold;       // base tokens out
        uint256 purchased;  // quote tokens in
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
    }
    
    function create(
        IERC20  _quoteToken,
        uint256 _baseVariable,
        uint256 _controlVariable,
        uint256 _vestingTerm,
        bool    _isActive
    ) external returns (uint256 id_);
    
    function enableMarket(uint256 _id, bool _enableMarket, address _swapHelper) external;
    
    function deposit(
        uint256 _id,
        uint256 _amount,
        uint256 _payoutMin,
        address _user,
        address _referral
    )
        external
        returns (
            uint256 payout_,
            uint256 epochCount_, 
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
    function payoutWithPrice(uint256 _amountUSDC, uint256 _price) external view returns (uint256 _payout);
    function bondValue(uint256 _id, uint256 _amount) external view returns (uint256 amountValue, uint256 btcAmount);
    function payoutFor(uint256 _id, uint256 _amountValue) external view returns (uint256 _payout, uint256 _payoutPrice);
    function payoutPrice(uint256 _id, uint256 _amountValue) external view returns (uint256 _payoutPrice);
    function bondDiscount(uint256 _id, uint256 _amountValue) external view returns (uint256 discount);
    function bondingValue(uint256 _amountValue) external view returns (uint256 bondingValueAmount);
    function currentControlVariable(uint256 _id) external view returns (uint256);
    function liveMarkets() external view returns (uint256[] memory);
}
