// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

interface IRebalancerHelper {
    function getAmountInForAdjust(uint reserveA, uint reserveB, uint priceBA2) external view returns (uint amountA);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external view returns (uint amountIn);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external view returns (uint amountOut);
    function getLiquidityFromMintFee(address factory, address tokenA, address tokenB) external view returns (uint liquidity);
    function getLiquidityAmount(address factory, address tokenA, address tokenB, uint256 amountA) external view returns (uint amountB);
    function getPrice(address factory, address tokenA, address tokenB) external view returns (uint priceAB);
    function getFairReserveB(uint256 reserveA, uint256 reserveB, uint256 decimalsA, uint256 oraclePriceAB) external view returns (uint fairReserveB);
}
