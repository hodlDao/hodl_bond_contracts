// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

interface IGenesis {
    function getGenesisInfo() external view returns(uint256 genesisAmount, uint256 bondAmount, uint256 priceGenesis, uint256 priceBond);
    function getUserGenesisInfo(address user) external view returns(uint256 genesisAmount, uint256 bondRate, uint256 bondRateLevel);
    function withdrawGenesis() external;
}
