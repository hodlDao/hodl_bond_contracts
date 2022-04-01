// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

interface ITreasury {
    function deposit(uint256 _amount, address _token, uint256 _btchAmount) external returns (uint256);
    function withdraw(uint256 _amount, address _token) external;
    function manage(address _token, uint256 _amount) external;
    function mint(address _recipient, uint256 _amount) external;
    
    function hodlValue() external view returns (uint256);
}
