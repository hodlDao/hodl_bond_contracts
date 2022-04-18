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

import "./interfaces/IBTCH.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IBondDepository.sol";
import "./interfaces/IPriceHelper.sol";
import "./interfaces/IRebalancerHelper.sol";

import "./interfaces/ISwapHelper.sol";
import "./interfaces/I20.sol";

contract Rebalancer is HodlAccessControlled {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    event RebalanceEvent(uint256 adjustType, uint256 rewardStaking, uint256 rewardInvoker, address invoker);
    
    modifier onlyWorker() {
        require(workers[msg.sender] == 1, "NoWorker");
        _;
    }
    
    uint256 public SQRTBN = 1e20;
    uint256 public SQRTBN2 = 1e40;
    
    uint256 public liquidityRate = 9900; //1e4
    uint256 public rewardPortionLevel = 10000;
    uint256 public rewardPortionUpwards = 100;
    uint256 public rewardPortionDownwards = 100;
    uint256 public rewardPortionInvokerLevel = 10000;
    uint256 public rewardPortionInvokerUpwards = 500;
    uint256 public rewardPortionInvokerDownwards = 500;
    
    bool    public priceGapAdjustEnabled = false;
    uint256 public priceGapAdjustPeriod = 3600*8;
    uint256 public priceGapAdjustLatest = 0;
    
    uint256 public priceGapFloor = 9700;
    uint256 public priceGapCeiling = 10300;
    uint256 public priceGapLevel = 10000;
    
    uint256 public usdc2wbtcPriceAllowed = 8000; //1e4 decimals.
    
    address[] public workersArray;
    mapping(address => uint) public workers;
    
    address public usdc;
    address public btch;
    address public wbtc;
    
    address public swapHelper;
    
    address public wbtc2usdcR;
    address public wbtc2usdcF;
    
    address public btch2wbtcR;
    address public btch2wbtcF;
    
    address public treasury;
    address public bondDepository;
    address public priceHelper;
    address public rebalancerHelper;
    
    constructor(IHodlAuthority _authority, address pUSDC, address pBTCH, address pWBTC) HodlAccessControlled(_authority) {
        usdc = pUSDC;
        btch = pBTCH;
        wbtc = pWBTC;
    }
    
    function setSwapHelper(address pSwapHelper, address pWbtc2usdcR, address pWbtc2usdcF, address pBtch2wbtcR, address pBtch2wbtcF) public onlyGovernorPolicy 
    {
        swapHelper = pSwapHelper;
        wbtc2usdcR = pWbtc2usdcR;
        wbtc2usdcF = pWbtc2usdcF;
        btch2wbtcR = pBtch2wbtcR;
        btch2wbtcF = pBtch2wbtcF;
    }
    
    function setTreasuryInfo(address pTreasury, address pBondDepository, address pPriceHelper, address pRebalancerHelper) public onlyGovernorPolicy 
    {
        treasury = pTreasury;
        bondDepository = pBondDepository;
        priceHelper = pPriceHelper;
        rebalancerHelper = pRebalancerHelper;
    }
    
    function setWorker(address pWorker, uint enabled) public onlyGovernorPolicy 
    {
        if(enabled == 1) {
            workersArray.push(pWorker);
        }
        
        workers[pWorker] = enabled;
    }
    
    function setRewardParameters(uint256 _liquidityRate, uint256 _rewardPortionUpwards, uint256 _rewardPortionDownwards, uint256 _rewardPortionInvokerUpwards, uint256 _rewardPortionInvokerDownwards) public onlyGovernorPolicy 
    {
        liquidityRate = _liquidityRate;
        rewardPortionUpwards = _rewardPortionUpwards;
        rewardPortionDownwards = _rewardPortionDownwards;
        rewardPortionInvokerUpwards = _rewardPortionInvokerUpwards;
        rewardPortionInvokerDownwards = _rewardPortionInvokerDownwards;
    }
    
    function setPriceGapParameters(uint256 _priceGapFloor, uint256 _priceGapCeiling) public onlyGovernorPolicy 
    {
        require(_priceGapCeiling >= 10100 && _priceGapFloor <= 9900, "NotAllowedRange");
        priceGapFloor = _priceGapFloor;
        priceGapCeiling = _priceGapCeiling;
    }
    
    function setRebalancerParameters(uint256 _usdc2wbtcPriceAllowed, uint256 _priceGapAdjustLatest, uint256 _priceGapAdjustPeriod) public onlyGovernorPolicy 
    {
        require(_usdc2wbtcPriceAllowed >= 8000 && _priceGapAdjustPeriod >= 3600, "NotAllowedRange");
        
        priceGapAdjustLatest = _priceGapAdjustLatest;
        if(priceGapAdjustLatest < block.timestamp)
            priceGapAdjustLatest = block.timestamp;
            
        usdc2wbtcPriceAllowed = _usdc2wbtcPriceAllowed;
        priceGapAdjustPeriod = _priceGapAdjustPeriod;
    }
    
    function enableLiquidityAction() public onlyGovernorPolicy 
    {
        require(bondDepository != address(0) && btch2wbtcF != address(0) && btch2wbtcR != address(0), "btch2wbtcFRNull");
        
        address lpAddr = IUniswapV2Factory(btch2wbtcF).getPair(btch, wbtc);
        require(lpAddr != address(0), "lpAddrNull");
        
        if(priceGapAdjustLatest > 0) 
            priceGapAdjustEnabled = true;

        IERC20(btch).safeApprove(bondDepository, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        IERC20(btch).safeApprove(btch2wbtcR, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        IERC20(wbtc).safeApprove(btch2wbtcR, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        IERC20(lpAddr).safeApprove(btch2wbtcR, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }
    
    function disableLiquidityAction() public onlyGovernorPolicy 
    {
        require(bondDepository != address(0) && btch2wbtcF != address(0) && btch2wbtcR != address(0), "btch2wbtcFRNull");
        
        address lpAddr = IUniswapV2Factory(btch2wbtcF).getPair(btch, wbtc);
        require(lpAddr != address(0), "lpAddrNull");
        
        if(priceGapAdjustLatest > 0) 
            priceGapAdjustEnabled = false;
            
        IERC20(btch).safeApprove(bondDepository, 0);
        IERC20(btch).safeApprove(btch2wbtcR, 0);
        IERC20(wbtc).safeApprove(btch2wbtcR, 0);
        IERC20(lpAddr).safeApprove(btch2wbtcR, 0);
    }
    
    function treasury2Liquidity(uint256 amountIn, uint256 amountOutMin) public onlyWorker returns (uint256 amountWBTC, uint256 amountBTCH) 
    {
        require(amountIn > 0, "NoAmountIn");
        
        //reuse amountWBTC to check amoutOutMin.
        uint256 decimalWBTC = I20(wbtc).decimals();
        amountWBTC = IPriceHelper(priceHelper).getBTCUSDC24();
        amountWBTC = amountIn.mul(10**decimalWBTC).div(amountWBTC).mul(usdc2wbtcPriceAllowed).div(1e4);
        require(amountWBTC <= amountOutMin, "amountOutMinTooLow");
        
        amountWBTC = swapUSDC2WBTC(amountIn, amountOutMin);
        
        amountBTCH = provideWBTC2Liquidity(amountWBTC);
    }
    
    //Prepare for WBTC bonding in future.
    function treasuryWBTC2Liquidity(uint256 amountIn) public onlyWorker returns (uint256 amountWBTC, uint256 amountBTCH) 
    {
        require(amountIn > 0, "NoAmountIn");
        
        amountWBTC = amountIn;
        ITreasury(treasury).withdraw(amountIn, wbtc);
        amountWBTC = IERC20(wbtc).balanceOf(address(this));
        
        amountBTCH = provideWBTC2Liquidity(amountWBTC);
    }
    
    function rebalance() public 
    {
        require(priceGapAdjustEnabled && block.timestamp >= priceGapAdjustLatest + priceGapAdjustPeriod, "RebalanceFrequencyNotAllowed");
        
        (uint256 adjustType, uint256 btch2wbtcDelta, uint256 btch2wbtc) = checkRebalanceCondition();
        
        uint btchDelta;
        if(adjustType == 1) {
            //left BTCHs
            btchDelta = upwardsAdjustBTCH2WBTC(btch2wbtcDelta, btch2wbtc);
            btchDelta = btchDelta.mul(rewardPortionUpwards).div(rewardPortionLevel);
            uint256 rewardInvoker = btchDelta.mul(rewardPortionInvokerUpwards).div(rewardPortionInvokerLevel);
            btchDelta = btchDelta.sub(rewardInvoker);
            IERC20(btch).safeTransfer(msg.sender, rewardInvoker);
            emit RebalanceEvent(adjustType, btchDelta, rewardInvoker, msg.sender);
            IBondDepository(bondDepository).depositForRebalance(adjustType, btchDelta, rewardInvoker, msg.sender, address(0));
            IBTCH(btch).burn(IERC20(btch).balanceOf(address(this)));
            priceGapAdjustLatest = block.timestamp;
            
        }
        else if(adjustType == 2) {
            //mint BTCHs
            btchDelta = downwardsAdjustBTCH2WBTC(btch2wbtcDelta, btch2wbtc);
            btchDelta = btchDelta.mul(rewardPortionDownwards).div(rewardPortionLevel);
            uint256 rewardInvoker = btchDelta.mul(rewardPortionInvokerDownwards).div(rewardPortionInvokerLevel);
            btchDelta = btchDelta.sub(rewardInvoker);
            emit RebalanceEvent(adjustType, btchDelta, rewardInvoker, msg.sender);
            IBondDepository(bondDepository).depositForRebalance(adjustType, btchDelta, rewardInvoker, msg.sender, address(0));
            priceGapAdjustLatest = block.timestamp;
        }
    }
    
    function checkRebalanceCondition() public view returns (uint256 adjustType, uint256 btch2wbtcDelta, uint256 btch2wbtc) {
        uint256 decimalWBTC = I20(wbtc).decimals();
        uint256 decimalUSDC = I20(usdc).decimals();
        uint targetPrice = IPriceHelper(priceHelper).getBTCUSDC365()/10000;
        uint marketPrice = IPriceHelper(priceHelper).getBTCHBTC24().mul(IPriceHelper(priceHelper).getBTCUSDC24()).div(10**decimalWBTC);

        uint wbtc2usdc = IRebalancerHelper(rebalancerHelper).getPrice(wbtc2usdcF, wbtc, usdc);
        btch2wbtc = IRebalancerHelper(rebalancerHelper).getPrice(btch2wbtcF, btch, wbtc);
        uint usdc2wbtc = IRebalancerHelper(rebalancerHelper).getPrice(wbtc2usdcF, usdc, wbtc);
        uint btch2usdc;
        
        adjustType = 0;
        uint256 priceHit = priceGapLevel * marketPrice / targetPrice;
        
        //upwards: marketPrice/targetPrice < priceGapFloor/priceGapLevel
        if(priceHit < priceGapFloor) {
            //upwards
            btch2usdc = btch2wbtc.mul(wbtc2usdc).div(10**decimalWBTC);
            priceHit = priceGapLevel.mul(btch2usdc).div(targetPrice);
            if(priceHit < priceGapFloor) {
                adjustType = 1;
                btch2wbtcDelta = targetPrice.sub(btch2usdc);
                btch2wbtcDelta = btch2wbtcDelta.mul(usdc2wbtc).div(10**decimalUSDC);
            }
        }
        else if(priceHit > priceGapCeiling) {
            //downwards
            btch2usdc = btch2wbtc.mul(wbtc2usdc).div(10**decimalWBTC);
            priceHit = priceGapLevel.mul(btch2usdc).div(targetPrice);
            if(priceHit > priceGapCeiling) {
                adjustType = 2;
                btch2wbtcDelta = btch2usdc.sub(targetPrice);
                btch2wbtcDelta = btch2wbtcDelta.mul(usdc2wbtc).div(10**decimalUSDC);
            }
        }
    }
    
    function getWBTC2USDCValue() public view returns (uint256 amount) {
        address lpAddr = IUniswapV2Factory(btch2wbtcF).getPair(btch, wbtc);
        uint256 decimalWBTC = I20(wbtc).decimals();
        uint256 liquidity = IERC20(lpAddr).balanceOf(treasury);
        require(liquidity > 0, "Wrong");
        
        uint256 totalSupply = IUniswapV2Pair(lpAddr).totalSupply();
        (uint reserveWBTC, uint reserveBTCH,) = IUniswapV2Pair(lpAddr).getReserves();
        if(wbtc > btch)
            (reserveWBTC, reserveBTCH) = (reserveBTCH, reserveWBTC);
        amount = reserveWBTC.mul(liquidity).div(totalSupply);
        
        amount = IPriceHelper(priceHelper).getBTCUSDC().mul(amount).div(10**decimalWBTC);
    }
    
    function upwardsAdjustBTCH2WBTC(uint256 btch2wbtcDelta, uint256 btch2wbtc) internal returns (uint256 btchDelta) {
        address lpAddr = IUniswapV2Factory(btch2wbtcF).getPair(btch, wbtc);
        uint256 liquidity = IERC20(lpAddr).balanceOf(treasury);
        require(liquidity > 0, "Wrong");
        
        liquidity = liquidity * liquidityRate / 10000;
        btchDelta = IERC20(btch).balanceOf(address(this));
        ITreasury(treasury).manage(lpAddr, liquidity);
        (uint amountBTCH, uint amountWBTC) = withdrawBTCH2WBTC(liquidity);
        
        (uint reserveWBTC, uint reserveBTCH,) = IUniswapV2Pair(lpAddr).getReserves();
        if(wbtc > btch)
            (reserveWBTC, reserveBTCH) = (reserveBTCH, reserveWBTC);
        
        //Reuse amountWBTC as priceBA2 for priceBTCH2WBTC.        
        amountWBTC = btch2wbtc.add(btch2wbtcDelta).mul(SQRTBN).div(1e9);
        amountWBTC = IRebalancerHelper(rebalancerHelper).getAmountInForAdjust(reserveWBTC, reserveBTCH, amountWBTC);
        require(IERC20(wbtc).balanceOf(address(this)) > amountWBTC, "NoAmounts1");
        
        amountBTCH = IRebalancerHelper(rebalancerHelper).getAmountOut(amountWBTC, reserveWBTC, reserveBTCH);
        swapWBTC2BTCH(amountWBTC, amountBTCH);
        
        amountWBTC = IERC20(wbtc).balanceOf(address(this));
        amountBTCH = IRebalancerHelper(rebalancerHelper).getLiquidityAmount(btch2wbtcF, wbtc, btch, amountWBTC);
        require(amountBTCH < IERC20(btch).balanceOf(address(this)), "NoAmounts2");
        
        (amountBTCH, amountWBTC, liquidity) = depositBTCH2WBTC(amountBTCH, amountWBTC);
        IERC20(lpAddr).safeTransfer(treasury, liquidity);
        
        amountBTCH = IERC20(btch).balanceOf(address(this));
        require(amountBTCH > btchDelta, "Wrong2");
        btchDelta = amountBTCH - btchDelta;
    }
    
    function downwardsAdjustBTCH2WBTC(uint256 btch2wbtcDelta, uint256 btch2wbtc) internal returns (uint256 btchDelta) {
        address lpAddr = IUniswapV2Factory(btch2wbtcF).getPair(btch, wbtc);
        uint256 liquidity = IERC20(lpAddr).balanceOf(treasury);
        require(liquidity > 0, "Wrong");
        
        liquidity = liquidity * liquidityRate / 10000;
        ITreasury(treasury).manage(lpAddr, liquidity);
        (uint amountBTCH, uint amountWBTC) = withdrawBTCH2WBTC(liquidity);
        
        (uint reserveWBTC, uint reserveBTCH,) = IUniswapV2Pair(lpAddr).getReserves();
        if(wbtc > btch)
            (reserveWBTC, reserveBTCH) = (reserveBTCH, reserveWBTC);
        
        //Reuse amountBTCH as priceBA2 for priceWBTC2BTCH.
        amountBTCH = 1e17; //9 decimals + 8 decimals.
        amountBTCH = amountBTCH.div(btch2wbtc.sub(btch2wbtcDelta)).mul(SQRTBN).div(1e8);
        amountBTCH = IRebalancerHelper(rebalancerHelper).getAmountInForAdjust(reserveBTCH, reserveWBTC, amountBTCH);
        
        //Reuse amountWBTC for balanceOf.
        amountWBTC = IERC20(btch).balanceOf(address(this));
        if(amountBTCH > amountWBTC) {
            btchDelta = amountBTCH - amountWBTC;
            ITreasury(treasury).mint(address(this), btchDelta);
        }
        
        amountWBTC = IRebalancerHelper(rebalancerHelper).getAmountOut(amountBTCH, reserveBTCH, reserveWBTC);
        swapBTCH2WBTC(amountBTCH, amountWBTC);
        
        amountWBTC = IERC20(wbtc).balanceOf(address(this));
        amountBTCH = IRebalancerHelper(rebalancerHelper).getLiquidityAmount(btch2wbtcF, wbtc, btch, amountWBTC);
        
        //Reuse reserveWBTC for balanceOf.
        reserveWBTC = IERC20(btch).balanceOf(address(this));
        if(amountBTCH > reserveWBTC) {
            btchDelta += amountBTCH - reserveWBTC;
            ITreasury(treasury).mint(address(this), amountBTCH - reserveWBTC);
        }
        
        (amountBTCH, amountWBTC, liquidity) = depositBTCH2WBTC(amountBTCH, amountWBTC);
        IERC20(lpAddr).safeTransfer(treasury, liquidity);
    }
    
    function swapUSDC2WBTC(uint256 amountIn, uint256 amountOutMin) internal returns (uint256 amountOut)
    {
        amountOut = IERC20(usdc).balanceOf(treasury);
        require(amountOut >= amountIn, "NotEnough");
        
        uint[] memory amountsOut = ISwapHelper(swapHelper).getAmountsOut(usdc, wbtc, amountIn);
        require(amountsOut[amountsOut.length-1] >= amountOutMin, "PriceFailure");
        
        ITreasury(treasury).withdraw(amountIn, usdc);
        IERC20(usdc).safeTransfer(swapHelper, amountIn);
        amountOut = IERC20(wbtc).balanceOf(address(this));
        ISwapHelper(swapHelper).swapExactTokensForTokens(usdc, wbtc, amountIn, amountOutMin);
        amountOut = IERC20(wbtc).balanceOf(address(this)).sub(amountOut);
        require(amountOut >= amountOutMin, "PriceFailure2");
    }
    
    function swapWBTC2BTCH(uint256 amountIn, uint256 amountOutMin) internal returns (uint256 amountOut)
    {
        uint[] memory amountsOut = ISwapHelper(swapHelper).getAmountsOut(wbtc, btch, amountIn);
        require(amountsOut[amountsOut.length-1] >= amountOutMin, "PriceFailure");
        
        amountOut = IERC20(btch).balanceOf(address(this));
        IERC20(wbtc).safeTransfer(swapHelper, amountIn);
        ISwapHelper(swapHelper).swapExactTokensForTokens(wbtc, btch, amountIn, amountOutMin);
        amountOut = IERC20(btch).balanceOf(address(this)).sub(amountOut);
        require(amountOut >= amountOutMin, "PriceFailure2");
    }
    
    function swapBTCH2WBTC(uint256 amountIn, uint256 amountOutMin) internal returns (uint256 amountOut)
    {
        uint[] memory amountsOut = ISwapHelper(swapHelper).getAmountsOut(btch, wbtc, amountIn);
        require(amountsOut[amountsOut.length-1] >= amountOutMin, "PriceFailure");
        
        amountOut = IERC20(wbtc).balanceOf(address(this));
        IERC20(btch).safeTransfer(swapHelper, amountIn);
        ISwapHelper(swapHelper).swapExactTokensForTokens(btch, wbtc, amountIn, amountOutMin);
        amountOut = IERC20(wbtc).balanceOf(address(this)).sub(amountOut);
        require(amountOut >= amountOutMin, "PriceFailure2");
    }
    
    function provideWBTC2Liquidity(uint256 amountWBTC) internal returns (uint256 amountBTCH) 
    {
        uint256 decimalWBTC = I20(wbtc).decimals();
        
        address lpAddr = IUniswapV2Factory(btch2wbtcF).getPair(btch, wbtc);
        uint256 liquidity = (lpAddr != address(0)) ? IUniswapV2Pair(lpAddr).totalSupply() : 0;
        
        if(liquidity == 0) {
            
            uint wbtc2usdc = IRebalancerHelper(rebalancerHelper).getPrice(wbtc2usdcF, wbtc, usdc);
            uint targetPrice = IPriceHelper(priceHelper).getBTCUSDC365()/10000;
            
            amountBTCH = amountWBTC.mul(wbtc2usdc).mul(1e9).div(10**decimalWBTC).div(targetPrice);
            ITreasury(treasury).mint(address(this), amountBTCH);
            
            (amountBTCH, amountWBTC, liquidity) = depositBTCH2WBTC(amountBTCH, amountWBTC);
            IERC20(lpAddr).safeTransfer(treasury, liquidity);
        }
        else {
            (uint reserveWBTC, uint reserveBTCH,) = IUniswapV2Pair(lpAddr).getReserves();
            if(wbtc > btch)
                (reserveWBTC, reserveBTCH) = (reserveBTCH, reserveWBTC);
                
            amountBTCH = amountWBTC.mul(reserveBTCH).div(reserveWBTC);
            ITreasury(treasury).mint(address(this), amountBTCH);
            
            (amountBTCH, amountWBTC, liquidity) = depositBTCH2WBTC(amountBTCH, amountWBTC);
            IERC20(lpAddr).safeTransfer(treasury, liquidity);
        }
        
        //First operation shall trigger rebalance allowance after 24 hours.
        if(priceGapAdjustLatest == 0) 
        {
            priceGapAdjustEnabled = true;
            priceGapAdjustLatest = block.timestamp + 3600*24 - priceGapAdjustPeriod;
        }
    }
    
    function depositBTCH2WBTC(uint256 btchAmount, uint256 wbtcAmount) internal returns (uint amountBTCH, uint amountWBTC, uint liquidity) {
        (amountWBTC, amountBTCH, liquidity) = IUniswapV2Router02(btch2wbtcR).addLiquidity(
            wbtc, 
            btch, 
            wbtcAmount, 
            btchAmount, 
            wbtcAmount, 
            btchAmount, 
            address(this),
            block.timestamp
            );
    }
    
    function withdrawBTCH2WBTC(uint256 liquidity) internal returns (uint amountBTCH, uint amountWBTC)  {
        (amountBTCH, amountWBTC) = IUniswapV2Router02(btch2wbtcR).removeLiquidity(
            btch, 
            wbtc,
            liquidity,
            0,
            0,
            address(this),
            block.timestamp
            );
    }
 
}
