const Multicall = artifacts.require("Multicall2");
const { getNetworkConfig } = require('../migration-config');


module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(Multicall);
};
