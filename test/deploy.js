const { time, expectEvent} = require("@openzeppelin/test-helpers");
const assert = require('chai').assert;
const Web3 = require('web3');
const config = require("../truffle-config.js");
const BN = require("bn.js");
var utils = require('./utils.js');
let web3  = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:7545"));

const Swaphelper = artifacts.require('MockSwapHelper');
const Genesis = artifacts.require('Genesis');
const Authority = artifacts.require('HodlAuthority');
const Treasure = artifacts.require('HodlTreasury');
const HoldStaking = artifacts.require('HodlStaking');
const Distributor = artifacts.require('Distributor');
const RebalancerHelper = artifacts.require('RebalancerHelper');
const PriceHelper =  artifacts.require('MockPriceHelper');
const HodlBondDepository = artifacts.require('HodlBondDepository');
const GenesisReward =  artifacts.require('GenesisReward');
const Rebalancer = artifacts.require('Rebalancer');
const sHodlERC20Token = artifacts.require("sHodlERC20Token");
const PreGenesis = artifacts.require("PreGenesisWithSafe");

let instSwaphelper = null;
let instGenesis = null;
let instAuthority = null;
let instTreasure = null;
let instHoldStaking = null;
let instDistributor = null;
let instRebalancerHelper = null;
let instPriceHelper = null;
let instBond = null;
let instGenesisReward = null;
let instRebalancer = null;
let instSBtch = null;
let instPreGenesis = null;

const Token = artifacts.require('MockERC20');
let tokenUSDT = null;
let tokenUSDC = null;
let tokenWBTC = null;
let tokenWETH = null;
let tokenBTCH = null;

let pAdminAddr = null;

async function deploySc(accounts) {
    pAdminAddr = accounts[0];

    tokenUSDT = await Token.new("USDT","USDT",18);
    tokenUSDC = await Token.new("USDC","USDC",18);
    tokenWBTC = await Token.new("WBTC","WBTC",18);
    tokenWETH = await Token.new("WETH","WETH",18);
    tokenBTCH = await Token.new("BTCH","BTCH",18);

    instSwaphelper = await Swaphelper.new(accounts[0],tokenWETH.address);
    instGenesis = await Genesis.new(accounts[0],tokenWETH.address,tokenUSDC.address);
    instAuthority = await Authority.new(accounts[0],accounts[0],accounts[0],accounts[0]);
    instSBtch = await sHodlERC20Token.new();

    instTreasure =  await Treasure.new(tokenBTCH.address,instAuthority.address);
    let nowtime =  new Date().getTime();
    instHoldStaking = await HoldStaking.new(tokenBTCH.address,instSBtch.address,100,0,nowtime/1000,instAuthority.address);

    instDistributor = await Distributor.new(instSBtch.address,instHoldStaking.address,instAuthority.address);

    instRebalancerHelper = await RebalancerHelper.new();
    instPriceHelper = await PriceHelper.new(tokenUSDC.address,tokenBTCH.address,tokenWBTC.address);

    instBond = await HodlBondDepository.new(instAuthority.address,
                                            instSBtch.address,
                                            instHoldStaking.address,
                                            instTreasure.address,
                                            instGenesis.address,
                                            instPriceHelper.address,
                                            tokenWBTC.address
                                          );

    instGenesisReward = await GenesisReward.new(instAuthority.address,
                                                tokenUSDC.address,
                                                instGenesis.address,
                                                instBond.address
                                               );

    instRebalancer = await Rebalancer.new(  instAuthority.address,
                                            tokenUSDC.address,
                                            tokenBTCH.address,
                                            tokenWBTC.address);

    instPreGenesis = await PreGenesis.new(accounts[0]);
}


async function initContracts(accounts) {
    if(pAdminAddr==null) {
        pAdminAddr = accounts[0];
    }
    let amount = webs.eth.toWei('100000000', 'ether');
    await tokenUSDT.mint(pAdminAddr,amount);
    await tokenUSDC.mint(pAdminAddr,amount);
    await tokenWBTC.mint(pAdminAddr,amount);

    await instSwaphelper.setWorker(instGenesis.address);
    await instSwaphelper.enableSwapInfo(tokenUSDT.address,tokenUSDC.address,false,instSwaphelper.address,[tokenUSDT.address,tokenUSDC.address]);
    await instSwaphelper.enableSwapInfo(tokenWBTC.address,tokenUSDC.address,false,instSwaphelper.address,[tokenWBTC.address,tokenUSDC.address]);
    await instSwaphelper.enableSwapInfo(tokenWETH.address,tokenUSDC.address,false,instSwaphelper.address,[tokenWETH.address,tokenUSDC.address]);

    await instGenesis.setParametersAddr(1,instSwaphelper.address);
    let nowtime =  new Date().getTime();
    await instGenesis.setParameters(1,nowtime);
    await instGenesis.setParameters(2,nowtime+24*3600*365);
    await instGenesis.setPreGenesis(instPreGenesis.address,1);
    await instGenesis.enableTokenInfo(tokenUSDC,address,false);
    await instGenesis.enableTokenInfo(tokenUSDT,address,false);
    await instGenesis.enableTokenInfo(tokenWBTC,address,false);
    await instGenesis.enableTokenInfo(tokenWETH,address,true);

    await instSwaphelper.changeOwner(pAdminAddr);
    await instGenesis.changeOwner(pAdminAddr);

    await tokenUSDT.approve(instGenesis.address,new BN(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
    await tokenUSDC.approve(instGenesis.address,new BN(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
    let fromAmountUSDT = webs.eth.toWei('2000', 'ether');
    let targetAmountUSDTMin = webs.eth.toWei('10', 'ether');
    await instGenesis.depositToken(tokenUSDT.address,fromAmountUSDT,targetAmountUSDTMin);

    let fromAmount = webs.eth.toWei('200000', 'ether');//200000*1e6,
    await instGenesis.depositToken(tokenUSDC.address,fromAmount,fromAmount);
    await instGenesis.setPreBondRate(20);

    await instAuthority.pushVault(instTreasure.address,true);

    await instHoldStaking.setDistributor(instDistributor.address);
    await instSBtch.setIndex(100000000);
    await instSBtch.initialize(instHoldStaking.address,instTreasure.address);
    await instSwaphelper.enableSwapInfo(tokenUSDC.address,tokenWBTC.address,false,instSwaphelper.address,[tokenUSDC.address,tokenWBTC.address]);
    await instSwaphelper.enableSwapInfo(tokenBTCH.address,tokenWBTC.address,false,instSwaphelper.address,[tokenBTCH.address,tokenWBTC.address]);
    await instSwaphelper.enableSwapInfo(tokenWBTC.address,tokenBTCH.address,false,instSwaphelper.address,[tokenWBTC.address,tokenBTCH.address]);

    await instPriceHelper.setSwapInfo(instRebalancerHelper.address,instSwaphelper.address,instSwaphelper.address,instSwaphelper.address );
    await instBond.create(tokenUSDC.address,8000,5000,3600*24*7,false);
    await instGenesis.setParametersAddr(2,instPriceHelper.address);
    await instGenesis.setParametersAddr(3,instGenesisReward.address);
    await instTreasure.enable(8,tokenBTCH.address);
    await instTreasure.enable(2,tokenUSDC.address);
    await instTreasure.enable(2,tokenWBTC.address);
    await instTreasure.enable(7,instBond.address);

    await instBond.updateParameters(instAuthority.address,tokenUSDC.address,tokenBTCH.address,tokenWBTC.address);
    await instRebalancer.setTreasuryInfo(instTreasure.address,instBond.address,instPriceHelper.address,instRebalancerHelper.address);
    await instSwaphelper.setWorker(instRebalancer.address,1);
    await instTreasure.enable(9,instRebalancer.address);
    await instTreasure.enable(1,instRebalancer.address);
    await instTreasure.enable(6,instRebalancer.address);
    await instTreasure.enable(7,instRebalancer.address);


    await instHoldStaking.setBondDepository(instBond.address);
    await instGenesis.setParameters(2,nowtime+24*3600*365);
    //await instGenesis.handlePreGenesisBatch(instPreGenesis.address,"");
    let btcUSDC365 = new BN(40000000000);
    let btcUSDC24 = new BN(45000000000);
    let btchBTC24 = new BN(10000);
    let btcUSDCTargetPrice =  new BN(40000000000);
    await instPriceHelper.simUpdate(btcUSDC365,btcUSDC24,btchBTC24,btcUSDCTargetPrice);
    await instGenesis.settleGenesis();

    await instRebalancer.setWorker(accounts[0],1);
    let usdc2wbtcPriceAllowed=8000;
    let btch2wbtcPriceRangeAllowed=2000;
    let priceGapAdjustLatest = 1650974400;
    let priceGapAdjustPeriod = 3600*8;
    await instRebalancer.setRebalancerParameters(usdc2wbtcPriceAllowed,btch2wbtcPriceRangeAllowed,priceGapAdjustLatest,priceGapAdjustPeriod);
    await instRebalancer.enableLiquidityAction();

    await instHoldStaking.enableRebase(nowtime);
    await instHoldStaking.rebase();
    await instHoldStaking.handleGenesis();

    // await instPriceHelper.simUpdate(btcUSDC365,btcUSDC24,btchBTC24);
    // let amountIn = webs.eth.toWei('2000', 'ether');;
    // let amountOutMin = 0;
    // let btch2wbtcDeltaRange = 2000;
    // await instRebalancer.treasury2Liquidity(amountIn,amountOutMin,btch2wbtcDeltaRange);

    /*
    { active: true, role: 'pUserAddr', command: 'USDC_approve', argNum: 2, args: ['BOND@', '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'] },
    { active: true, role: 'pUserAddr', command: 'BOND_deposit', argNum: 5, args: [Config.marketId, Config.bondAmountIn, Config.bondPayoutMin, Config.pUserAddr, '0x0000000000000000000000000000000000000000'] },
    */

    // { active: false, role: 'pWorkAddr', command: 'PRICEHELPER_simUpdate', argNum: 3, args: [Config.btcUSDC365, Config.btcUSDC24, Config.btchBTC24] },
    // { active: false, role: 'pRebalanceWorker', command: 'REBALANCER_treasury2Liquidity', argNum: 3, args: [Config.amountIn, Config.amountOutMin, Config.btch2wbtcDeltaRange] },
    // { active: false, role: 'pRebalanceWorker', command: 'REBALANCER_treasuryWBTC2Liquidity', argNum: 2, args: [Config.amountInWBTC, Config.btch2wbtcDeltaRange] },
    //
    // { active: false, role: 'pUserAddr', command: 'BOND_redeemGenesis', argNum: 1, args: [true] },
    // { active: false, role: 'pUserAddr', command: 'BOND_redeemAll', argNum: 2, args: [Config.pUserAddr, true] },

    /*
    { active: true, role: 'pUserAddr', command: 'BTCH_approve', argNum: 2, args: ['STAKING@', '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'] },
    { active: true, role: 'pUserAddr', command: 'SBTCH_approve', argNum: 2, args: ['STAKING@', '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'] },
    { active: true, role: 'pUserAddr', command: 'STAKING_stake', argNum: 2, args: [Config.pUserAddr, 1e9] },
    { active: true, role: 'pUserAddr', command: 'STAKING_unstake', argNum: 2, args: [Config.pUserAddr, 1e9] },
    */

    // { active: false, role: 'pWorkAddr', command: 'STAKING_rebase', argNum: 0, args: [] },
    // { active: false, role: 'pGovernor', command: 'REBALANCER_setRebalancerParameters', argNum: 4, args: [Config.usdc2wbtcPriceAllowed, Config.btch2wbtcPriceRangeAllowed, Config.priceGapAdjustLatest, Config.priceGapAdjustPeriod] },
    // { active: false, role: 'pWorkAddr', command: 'PRICEHELPER_simUpdate', argNum: 3, args: [Config.btcUSDC365, Config.btcUSDC24, Config.btchBTC24] },
    // { active: false, role: 'pRebalanceWorker', command: 'REBALANCER_rebalance', argNum: 0, args: [] },
    // { active: false, role: 'pPolicy', command: 'BOND_updateBondInfo', argNum: 3, args: [Config.marketId, Config.baseVariable, Config.controlVariable] },

 }

exports.instSwaphelper = instSwaphelper;
exports.instGenesis = instGenesis;
exports.instAuthority = instAuthority;
exports.instTreasure = instTreasure;
exports.instHodlStaking = instHoldStaking;
exports.instDistributor = instDistributor;
exports.instRebalancerHelper = instRebalancerHelper;
exports.instPriceHelper = instPriceHelper;
exports.instHodlBondDepository = instBond;
exports.instGenesisReward = instGenesisReward;
exports.instRebalancer = instRebalancer;
exports.pAdminAddr = pAdminAddr;
exports.web3 = web3;
exports.deploySc = deploySc;
exports.initContracts = initContracts;