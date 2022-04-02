const LPFeeManagerV2 = artifacts.require("LPFeeManagerV2");
const { getNetworkConfig } = require('../migration-config');
const { deployProxy, admin } = require('@openzeppelin/truffle-upgrades');

module.exports = async function (deployer, network, accounts) {
    const { routerAddress } = getNetworkConfig(network, accounts);
    // const deployer = accounts[0];
    const adminAddress = '0x6c905b4108A87499CEd1E0498721F2B831c6Ab13'; // BSC General Admin EOA
    const proxyAdminAddress = '0xf81A0Ee9BB9606e375aeff30364FfA17Bb8a7FD1'; // BSC General Proxy Admin EOA
    // NOTE: Test admin address
    // const adminAddress = '0x5c7C7246bD8a18DF5f6Ee422f9F8CCDF716A6aD2';
    // const proxyAdminAddress = '0x033996008355D0BE4E022c00f06F844547e23dcF'; // BSC General Proxy Admin EOA

    await deployProxy(LPFeeManagerV2, [
        routerAddress
      ], { deployer });
    //   Using proxy admin contract instead
    // await admin.changeProxyAdmin(LPFeeManagerV2.address, proxyAdminAddress);


    // await deployer.deploy(LPFeeManagerV2, routerAddress, [], true);
    const lpFeeManagerV2 = await LPFeeManagerV2.at(LPFeeManagerV2.address);
    await lpFeeManagerV2.transferOwnership(adminAddress);
    const owner = await lpFeeManagerV2.owner();

    console.dir({
        lpFeeManagerV2: lpFeeManagerV2.address,
        owner,
    })
};
