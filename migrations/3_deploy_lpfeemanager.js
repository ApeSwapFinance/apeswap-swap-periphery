const LPFeeManagerV2 = artifacts.require("LPFeeManagerV2");
const { getNetworkConfig } = require('../migration-config');

module.exports = async function (deployer, network, accounts) {
    const { routerAddress } = getNetworkConfig(network, accounts);
    // const deployer = accounts[0];
    const adminAddress = '0x6c905b4108A87499CEd1E0498721F2B831c6Ab13'; // BSC General Admin EOA
    // NOTE: Test admin address
    // const adminAddress = '0x5c7C7246bD8a18DF5f6Ee422f9F8CCDF716A6aD2';
    await deployer.deploy(LPFeeManagerV2, routerAddress, [], true);
    const lpFeeManagerV2 = await LPFeeManagerV2.at(LPFeeManagerV2.address);
    await lpFeeManagerV2.transferOwnership(adminAddress);
    const owner = await lpFeeManagerV2.owner();

    console.dir({
        lpFeeManagerV2: lpFeeManagerV2.address,
        owner,
    })
};
