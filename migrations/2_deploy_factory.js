const ApeRouter = artifacts.require("PancakeRouter");

const { config } = require('./migration-config');

//constructor(address _factory, address _WETH) public {

module.exports = function (deployer, network, accounts) {
  deployer.deploy(ApeRouter, config[network].factoryAddress, config[network].WBNBAddress);
};
