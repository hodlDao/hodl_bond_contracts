// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

interface IRebalancer {
    function getWBTC2USDCValue() external view returns (uint256 amount);
}