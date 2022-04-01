// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

interface IPriceHelper {
    function getBTCUSDC365() external view returns(uint256);
    function getBTCUSDC24() external view returns(uint256);
    function getBTCUSDC() external view returns(uint256);
    function getBTCHBTC24() external view returns(uint256);
    function getBTCHBTC() external view returns(uint256);
    function update() external;
}
