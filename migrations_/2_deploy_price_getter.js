const PriceGetter = artifacts.require("ApeOnlyPriceGetterArbitrum");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(PriceGetter);
};
