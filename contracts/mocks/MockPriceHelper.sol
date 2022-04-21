// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.4;

import "../interfaces/IERC20.sol";
import "../lib/SafeERC20.sol";
import "../lib/SafeMath.sol";
import "../lib/Math.sol";

import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IRebalancerHelper.sol";

contract MockPriceHelper {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    modifier onlyWorker() {
        require(workers[msg.sender] == 1, "NoWorker");
        _;
    }
    
    uint256 public btcusdc365;
    uint256 public btcusdc24;
    uint256 public btchbtc24;
    
    address public usdc;
    address public btch;
    address public wbtc;
    
    address public rebalancerHelper;
    address public wbtc2usdcR;
    address public wbtc2usdcF;
    address public btch2wbtcR;
    address public btch2wbtcF;
    
    address[] public workersArray;
    mapping(address => uint) public workers;
     
    constructor(address pUSDC, address pBTCH, address pWBTC) {
        usdc = pUSDC;
        btch = pBTCH;
        wbtc = pWBTC;
        workersArray.push(msg.sender);
        workers[msg.sender] = 1;
    }
    
    function setSwapInfo(address pRebalancerHelper, address pWbtc2usdcR, address pWbtc2usdcF, address pBtch2wbtcR, address pBtch2wbtcF) public onlyWorker 
    {
        rebalancerHelper = pRebalancerHelper;
        wbtc2usdcR = pWbtc2usdcR;
        wbtc2usdcF = pWbtc2usdcF;
        btch2wbtcR = pBtch2wbtcR;
        btch2wbtcF = pBtch2wbtcF;
    }
     
    function setWorker(address pWorker, uint enabled) public onlyWorker 
    {
        if(enabled == 1) {
            workersArray.push(pWorker);
        }
        
        workers[pWorker] = enabled;
    }
    
    function getBTCUSDC365() public view returns(uint256)
    {
        //require(btcusdc365 > 0, "NoPrice");
        return btcusdc365;
    }
    
    function getBTCUSDC24() public view returns(uint256)
    {
        //require(btcusdc24 > 0, "NoPrice");
        return btcusdc24;
    }
    
    function getBTCHBTC24() public view returns(uint256)
    {
        //require(btchbtc24 > 0, "NoPrice");
        return btchbtc24;
    }
    
    function getBTCUSDC() public view returns(uint256)
    {
        uint wbtc2usdc = IRebalancerHelper(rebalancerHelper).getPrice(wbtc2usdcF, wbtc, usdc);
        return wbtc2usdc;
    }
    
    function getBTCHBTC() public view returns(uint256)
    {
        uint btch2wbtc = IRebalancerHelper(rebalancerHelper).getPrice(btch2wbtcF, btch, wbtc);
        return btch2wbtc;
    }
    
    function simUpdate(uint256 pBTCUSDC365, uint256 pBTCUSDC24, uint256 pBTCHBTC24) public onlyWorker
    {
        btcusdc365 = pBTCUSDC365;
        btcusdc24 = pBTCUSDC24;
        btchbtc24 = pBTCHBTC24;
    }
    
    function update() public 
    {
    }
 
}
