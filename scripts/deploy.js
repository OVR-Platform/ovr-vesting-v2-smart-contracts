// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  const ovrTokenEthereum = "0x21BfBDa47A0B4B5b1248c767Ee49F7caA9B23697";
  // We get the contract to deploy
  const Contract = await hre.ethers.getContractFactory("OVRVestingV2");
  const contract = await Contract.deploy(ovrTokenEthereum);

  await contract.deployed();

  console.log("OVRVestingV2 deployed to:", contract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
