var Market1 = artifacts.require("./Market.sol");

module.exports = function(deployer, network, accounts)
{
  // Deploys the OraclizeTest contract and funds it with 0.5 ETH
// The contract needs a balance > 0 to communicate with Oraclize
  deployer.deploy(Market1, 60000000, { from: accounts[9], value: 20000000000000000000 });
};