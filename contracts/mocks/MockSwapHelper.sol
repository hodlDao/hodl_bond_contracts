// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.4;

import "./IMERC20.sol";
import "./SafeERC20.sol";
import "../lib/SafeMath.sol";

interface INative {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function balanceOf(address owner) external view returns (uint);
    function withdraw(uint) external;
}

contract MockSwapHelper {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    struct SwapInfo {
        bool isActive;
        bool fromNative;
        address fromToken;
        address toToken;
        address router;
        address[] path;
    }
    
    modifier onlyWorker() {
        require(workers[msg.sender] == 1, "NoWorker");
        _;
    }
    
    modifier onlySwapOwner() {
        require(msg.sender == admin, "NoOwner");
        _;
    }
    
    modifier tokenSwapSupported(address fromToken, address toToken) {
        require(tokenSwapMap[fromToken][toToken].isActive, "NotSupported");
        _;
    }
    
    address public admin;
    
    address public nativeToken;
    
    address[] public workersArray;
    mapping(address => uint) public workers;
    
    mapping(address => mapping(address => SwapInfo)) public tokenSwapMap;
    
    receive() external payable {
    }
    
    constructor(address pAdmin, address pNativeToken) {
        admin = pAdmin;
        nativeToken = pNativeToken;
    }
    
    function changeOwner(address pOwner) 
        public 
        onlySwapOwner 
    {
        admin = pOwner;
    }
    
    function setWorker(address pWorker, uint enabled) 
        public 
        onlySwapOwner 
    {
        if(enabled == 1) {
            workersArray.push(pWorker);
        }
        
        workers[pWorker] = enabled;
    }
    
    function enableSwapInfo(address fromToken, address toToken, bool fromNative, address router, address[] calldata path)
        public
        onlySwapOwner
    {
        IERC20(fromToken).safeApprove(router, 0);
        IERC20(fromToken).safeApprove(router, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        tokenSwapMap[fromToken][toToken] = SwapInfo({
            isActive: true,
            fromNative: fromNative,
            fromToken: fromToken,
            toToken: toToken,
            router: router,
            path: path
        });
    }
    
    function disableSwapInfo(address fromToken, address toToken)
        public
        onlySwapOwner
    {
        SwapInfo storage swapInfo = tokenSwapMap[fromToken][toToken];
        require(swapInfo.isActive, "NotSupported");
        
        IERC20(fromToken).safeApprove(swapInfo.router, 0);
        tokenSwapMap[fromToken][toToken].isActive = false;
    }
    
    function isTokenSwapSupport(address fromToken, address toToken)
        public
        view
        returns (bool support)
    {
        SwapInfo storage swapInfo = tokenSwapMap[fromToken][toToken];
        support = swapInfo.isActive;
    }
    
    function getAmountsOut(address fromToken, address toToken, uint fromAmount) 
        public 
        view 
        returns (uint[] memory amounts) 
    {
        SwapInfo storage swapInfo = tokenSwapMap[fromToken][toToken];
        require(swapInfo.isActive, "NotSupported");

        amounts[0]=fromAmount;

       // amounts = IRouter(swapInfo.router).getAmountsOut(fromAmount, swapInfo.path);
    }
    
    //Require worker has already transferred the fromAmount to this contract.
    //The swapped toToken is transferred to msg.sender.
    function swapExactTokensForTokens(address fromToken, address toToken, uint fromAmount, uint amountOutMin)
        public
        onlyWorker
    {
        SwapInfo storage swapInfo = tokenSwapMap[fromToken][toToken];
        require(swapInfo.isActive, "NotSupported");
        
        if(fromToken == nativeToken) {
            uint balance = address(this).balance;
            if(balance > 0) {
                INative(fromToken).deposit{value: balance}();
            }
        }
        
        uint tokenBalance = IERC20(fromToken).balanceOf(address(this));
        require(tokenBalance >= fromAmount, "LessAmount");

        IMERC20(fromToken).burn(msg.sender,fromAmount);
        IMERC20(toToken).mint(msg.sender,fromAmount);
        amountOutMin = 0;
      //  IRouter(swapInfo.router).swapExactTokensForTokens(fromAmount, amountOutMin, swapInfo.path, msg.sender, block.timestamp);
    }

}
