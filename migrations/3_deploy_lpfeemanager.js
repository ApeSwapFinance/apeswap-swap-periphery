const LPFeeManagerV2 = artifacts.require("LPFeeManagerV2");
const { getNetworkConfig } = require('../migration-config');


module.exports = async function (deployer, network, accounts) {
    const { routerAddress } = getNetworkConfig(network, accounts);
    await deployer.deploy(LPFeeManagerV2, routerAddress, "0x5c7C7246bD8a18DF5f6Ee422f9F8CCDF716A6aD2", [], true);
};
