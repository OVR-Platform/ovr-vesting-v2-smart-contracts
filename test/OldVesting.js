const { time } = require("@openzeppelin/test-helpers");
const { ethers } = require("hardhat");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

const cyan = "\x1b[36m%s\x1b[0m";
const yellow = "\x1b[33m%s\x1b[0m";

const DAY = 86400;
const MONTH = DAY * 30; // Supposing every month 30 days
const HOUR = DAY / 24; // Supposing every month 30 days
const YEAR = MONTH * 12;

const displayTime = (unixTime) => {
  const date = new Date(unixTime * 1000).toLocaleString("it-IT");
  return date;
};

const displayBlockTime = async () => {
  const currentBlock = await time.latest();
  const currentBlockNumber = await time.latestBlock();

  console.debug("\t\t\tCurrent Block Number", currentBlockNumber.toString());
  console.debug("\t\t\tCurrent Block Timestamp", currentBlock.toString());
  console.debug(
    "\t\t\tCurrent Block Time",
    displayTime(Number(currentBlock.toString()))
  );
};

const displayBalance = async (user, contract, logText) => {
  const balance = await contract.balanceOf(user.address);
  console.debug(`\t\t\t${logText} ${yellow}`, fromWei(balance.toString()));
};

const fromWei = (stringValue) => ethers.utils.formatUnits(stringValue, 18);
const toWei = (value) => ethers.utils.parseEther(value);

describe.only("Old Vesting", () => {
  let Vesting, OVRToken;
  let vesting, ovrToken;

  beforeEach(async () => {
    Vesting = await ethers.getContractFactory("OVRVesting");
    OVRToken = await ethers.getContractFactory("OVRToken");

    [
      owner, // 50 ether
      addr1, // 0
      addr2, // 0
      addr3, // 0
      addr4, // 0
      addr5, // 0
      addr6, // 0
      addr7, // 0
      addr8, // 0
      addr9, // 0
      addr10, // 0
      addr11, // 0
      addr12, // 0
      addr13, // 0
      addr14, // 0
      addr15, // 0
      addr16, // 0
      addr17, // 0
      addr18, // 1000 ether
    ] = await ethers.getSigners();
  });

  describe("Deployment", () => {
    it("Should deploy", async () => {
      ovrToken = await OVRToken.deploy();
      await ovrToken.deployed();

      await displayBalance(owner, ovrToken, "Owner Balance");
      vesting = await Vesting.deploy(ovrToken.address);
      await displayBlockTime();
      await vesting.deployed();
    });

    // it("Trasfer 100000 OVR to addr1", async () => {
    //   await ovrToken.connect(owner).transfer(addr1.address, toWei("100000"));
    //   const bal = await ovrToken.connect(addr1).balanceOf(addr1.address);
    //   await displayBalance(addr1, ovrToken, "Addr1 Balance");
    //   expect(fromWei(bal.toString())).to.equal("100000.0");
    // });
    // it("Trasfer 100000 OVR to addr2", async () => {
    //   await ovrToken.connect(owner).transfer(addr2.address, toWei("100000"));
    //   const bal = await ovrToken.connect(addr2).balanceOf(addr2.address);
    //   await displayBalance(addr2, ovrToken, "Addr2 Balance");
    //   expect(fromWei(bal.toString())).to.equal("100000.0");
    // });
  });

  describe("Tests", () => {
    it("Granting and transfer token to contract", async () => {
      await vesting.granting(addr1.address, toWei("100000"), true);
      await ovrToken.connect(owner).transfer(vesting.address, toWei("100000"));
      await displayBalance(vesting, ovrToken, "Vesting Balance");
    });

    it("Move time forward 1 Year", async () => {
      await time.increase(YEAR * 0.9);
      displayBlockTime();
    });

    it("Withdraw", async () => {
      await vesting.connect(addr1).unlockVestedTokens();
      await displayBalance(vesting, ovrToken, "Vesting Balance");
      await displayBalance(addr1, ovrToken, "Addr1 Balance");
    });

    it("Move time forward 1 Year", async () => {
      await time.increase(YEAR * 0.5);
      displayBlockTime();
    });

    it("Withdraw", async () => {
      await vesting.connect(addr1).unlockVestedTokens();
      await displayBalance(vesting, ovrToken, "Vesting Balance");
      await displayBalance(addr1, ovrToken, "Addr1 Balance");
    });
  });
});
