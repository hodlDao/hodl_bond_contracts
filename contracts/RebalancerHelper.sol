// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.4;

import "./interfaces/IERC20.sol";
import "./lib/SafeERC20.sol";
import "./lib/SafeMath.sol";
import "./lib/Math.sol";

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";

import "./types/HodlAccessControlled.sol";

import "./interfaces/ITreasury.sol";
import "./interfaces/IBondDepository.sol";
import "./interfaces/IPriceHelper.sol";

import "./interfaces/ISwapHelper.sol";
import "./interfaces/I20.sol";

contract RebalancerHelper {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    uint256 public SQRTBN = 1e20;
    uint256 public SQRTBN2 = 1e40;
    
    constructor() {
    }
     
    //Requirement: priceBA2 > priceBA
    //Formula: priceBA2 = SQRTBN*reserveA/reserveB = SQRTBN*getPrice()/(10**decimalB)
    //Formula: (1+aI/rI) * (1+aI/rI*997/1000) * priceBA >= priceBA2
    //Note: priceBA2 are scaled with SQRTBN.
    //x = aI/rI
    //997/1000*x2 + 1997/1000*x +1 >= priceBA2/priceBA
    //A*x2 + B*x - C >= 0
    //(x + B/2A)2 >= C/A + (B/2A)2
    function getAmountInForAdjust(uint reserveA, uint reserveB, uint priceBA2) public view returns (uint amountA) {
        uint priceBA = SQRTBN.mul(reserveA).div(reserveB);
        uint A = SQRTBN.mul(997).div(1000);
        uint B = SQRTBN.mul(1997).div(1000);
        uint C = SQRTBN.mul(priceBA2).div(priceBA).sub(SQRTBN);
        uint x = SQRTBN.mul(B).div(A).div(2);
        x = x.mul(x);
        x = SQRTBN2.mul(C).div(A).add(x);
        x = Math.sqrt(x);
        x = x.sub(SQRTBN.mul(B).div(A).div(2));
        amountA = x.mul(reserveA).div(SQRTBN);
    }
    
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public pure returns (uint amountIn) {
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }
    
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }
    
    function getLiquidityFromMintFee(address factory, address tokenA, address tokenB) public view returns (uint liquidity) {
        address lpAddr = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        require(lpAddr != address(0), "InvalidLP");
        
        (uint reserveA, uint reserveB,) = IUniswapV2Pair(lpAddr).getReserves();
        require(reserveA > 0 && reserveB > 0, "InvalidReserves");
        uint kLast = IUniswapV2Pair(lpAddr).kLast();
        
        liquidity = 0;
        
        address feeTo = IUniswapV2Factory(factory).feeTo();
        if(feeTo != address(0) && kLast != 0) {
            uint rootK = Math.sqrt(uint(reserveA).mul(reserveB));
            uint rootKLast = Math.sqrt(kLast);
            if (rootK > rootKLast) {
                uint numerator = IUniswapV2Pair(lpAddr).totalSupply().mul(rootK.sub(rootKLast));
                uint denominator = rootK.mul(5).add(rootKLast);
                liquidity = numerator / denominator;
            }
        }
    }
    
    function getLiquidityAmount(address factory, address tokenA, address tokenB, uint256 amountA) public view returns (uint amountB) {
        address lpAddr = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        require(lpAddr != address(0), "InvalidLP");
        
        (uint reserveA, uint reserveB,) = IUniswapV2Pair(lpAddr).getReserves();
        require(reserveA > 0 && reserveB > 0, "InvalidReserves");
        
        if(tokenA > tokenB)
            (reserveA, reserveB) = (reserveB, reserveA);
            
        amountB = amountA.mul(reserveB).div(reserveA);
    }
    
    function getPrice(address factory, address tokenA, address tokenB) public view returns (uint priceAB) {
        uint256 decimalA = I20(tokenA).decimals();
        priceAB = getLiquidityAmount(factory, tokenA, tokenB, 10**decimalA);
    }
 
}
