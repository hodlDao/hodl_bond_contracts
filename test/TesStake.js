const { time, expectEvent} = require("@openzeppelin/test-helpers");
const BN = require("bn.js");
var deployer = require('./deploy.js');


/**************************************************
 test case only for the ganahce command
 ganache-cli --port=7545 --gasLimit=8000000 --accounts=10 --defaultBalanceEther=100000 --blockTime 1
 **************************************************/
contract('test stakes', function (accounts){

  before("init", async()=>{
     deployer.deploySc(accounts);
     deployer.initContracts(accounts);
  })

  it("[0010] stake in,should pass", async()=>{
    console.log("will stake")
  })
})