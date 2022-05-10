const priceGetter = artifacts.require("ApeOnlyPriceGetter");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(priceGetter);
};
