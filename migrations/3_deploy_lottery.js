const Lottery = artifacts.require("Lottery");
const KitCoin = artifacts.require("KitCoin");
const ethers = require("ethers");

module.exports = async function (deployer) {
  const kitCoinIns = await KitCoin.deployed();
  deployer.deploy(Lottery, kitCoinIns.address, ethers.utils.parseEther("100"));
};
