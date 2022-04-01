// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

interface IBondCalculator {
    function valuation(address token, uint256 decimals, uint256 amount) external view returns (uint256 value);
}
