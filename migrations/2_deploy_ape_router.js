const ApeRouter = artifacts.require("ApeRouter");
const WMATIC = artifacts.require("WMATIC");
const { getNetworkConfig } = require('../migration-config');


module.exports = async function (deployer, network, accounts) {
  const { factoryAddress, wrappedAddress } = getNetworkConfig(network, accounts);

  let finalWrappedAddress = wrappedAddress;
  if(!finalWrappedAddress || finalWrappedAddress == '0x') {
    console.log(`Wrapped address is empty. Deploying new wrapped contract.`);
    await deployer.deploy(WMATIC);
    finalWrappedAddress = (await WMATIC.deployed()).address;
  };
  
  await deployer.deploy(ApeRouter, factoryAddress, finalWrappedAddress);
};
