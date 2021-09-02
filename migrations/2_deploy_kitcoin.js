const KitCoin = artifacts.require("KitCoin");

module.exports = function (deployer) {
  deployer.deploy(KitCoin);
};
