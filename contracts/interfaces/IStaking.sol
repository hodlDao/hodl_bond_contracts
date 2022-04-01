// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

interface IStaking {
    function stake(address _to, uint256 _amount) external returns (uint256 amount_);
    function unstake(address _to, uint256 _amount) external returns (uint256 amount_);
    
    function rebase() external;

    function index() external view returns (uint256);
    function secondsToNextEpoch() external view returns (uint256);
    function epochNumber() external view returns (uint256 curEpoch, uint256 curEpochEndTime);
    function epochLength() external view returns (uint256 _epochLength);
    
    function setDistributor(address _distributor) external;
}
