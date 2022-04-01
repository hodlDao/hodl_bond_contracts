// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

interface ISwapHelper {
    function isTokenSwapSupport(address fromToken, address toToken) external view returns (bool);
    function getAmountsOut(address fromToken, address toToken, uint fromAmount) external view returns (uint[] memory);
    function swapExactTokensForTokens(address fromToken, address toToken, uint fromAmount, uint amountOutMin) external;
}
