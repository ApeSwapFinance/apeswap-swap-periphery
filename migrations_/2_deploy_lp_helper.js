const LiquidityHelper = artifacts.require("LiquidityHelper");
const { getNetworkConfig } = require('../migration-config');


module.exports = async function (deployer, network, accounts) {
  const { factoryAddress, wrappedAddress } = getNetworkConfig(network, accounts);
  await deployer.deploy(LiquidityHelper, factoryAddress);
};
