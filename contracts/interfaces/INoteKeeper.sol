// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.4;

import "./ITreasury.sol";
import "./IGenesis.sol";
import "./IPriceHelper.sol";

interface INoteKeeper {
   
    // Info for market note
    struct Note {
        uint256 payout;  //  sBTCH gons for bond.
        uint256 payoutRemain; //  sBTCH gons remain for bond.
        uint48 created;  //  timestamp market was created.
        uint48 matured;  //  timestamp when market is matured and expired.
        uint48 redeemed; //  timestamp market was redeemed.
        uint48 marketID; //  market ID of deposit. uint48 to avoid adding a slot.
    }

    function updateParameters(
        ITreasury _treasury,
        IGenesis _genesis,
        IPriceHelper _priceHelper,
        address _genesisReward,
        address _rebalancer,
        bool _triggerPriceUpdate
    ) external;
    
    function redeem(address _user, uint256[] memory _indexes) external returns (uint256);
    function redeemAll(address _user) external returns (uint256);
    
    function redeemGenesis() external returns (uint256 payout_);

    function indexesFor(address _user) external view returns (uint256[] memory);
    function pendingFor(address _user, uint256 _index) external view returns (uint256 payout_);
    
    function pendingForGenesis0123(uint256 _totalAmount, uint256 _userAmount, uint256 _type, address _user) external view returns (uint256 payout_);
    function pendingGenesis(address user) external view returns (uint256 _payout);
}
