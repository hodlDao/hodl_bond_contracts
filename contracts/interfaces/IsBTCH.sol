// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

import "./IERC20.sol";

interface IsBTCH is IERC20 {
    function rebase(uint256 ohmProfit_, uint256 epoch_) external returns (uint256);
    function circulatingSupply() external view returns (uint256);
    function gonsForBalance(uint256 amount) external view returns (uint256);
    function balanceForGons(uint256 gons) external view returns (uint256);
    function gonsForBalancePerEpoch(uint256 amountPerEpoch, uint256 fromEpoch, uint256 toEpoch) external view returns (uint256);
    function index0() external view returns (uint256);
    function index() external view returns (uint256);
}
