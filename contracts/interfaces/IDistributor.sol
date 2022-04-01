// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

interface IDistributor {
    function distributeAmount() external view returns (uint256);
    function setInfoRate(uint256 _infoRate) external;
}
