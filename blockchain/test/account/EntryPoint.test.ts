import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { PropellantBDEntryPoint } from "../../typechain-types";

describe("PropellantBDEntryPoint", function () {
  // Fixture to deploy the EntryPoint
  async function deployEntryPointFixture() {
    const [deployer, user1, user2] = await hre.ethers.getSigners();
    
    const EntryPointFactory = await hre.ethers.getContractFactory("PropellantBDEntryPoint");
    const entryPoint = await EntryPointFactory.deploy();
    
    return { entryPoint, deployer, user1, user2 };
  }
  
  describe("Deployment", function () {
    it("Should deploy successfully", async function () {
      const { entryPoint } = await loadFixture(deployEntryPointFixture);
      expect(entryPoint.target).to.not.equal(hre.ethers.ZeroAddress);
    });
    
    it("Should return the correct version", async function () {
      const { entryPoint } = await loadFixture(deployEntryPointFixture);
      expect(await entryPoint.version()).to.equal("1.0.0");
    });
  });
});