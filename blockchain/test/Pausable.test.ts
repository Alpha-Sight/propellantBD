import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { Pausable } from "../typechain-types";

describe("Pausable", function () {
  // Fixture to deploy a fresh Pausable contract for each test
  async function deployPausableFixture() {
    const [admin, otherAccount] = await hre.ethers.getSigners();
    
    const PausableFactory = await hre.ethers.getContractFactory("Pausable");
    const pausable = await PausableFactory.deploy();
    
    const PAUSER_ROLE = await pausable.PAUSER_ROLE();
    
    return { pausable, admin, otherAccount, PAUSER_ROLE };
  }
  
  describe("Deployment", function () {
    it("Should set the deployer as a pauser", async function () {
      const { pausable, admin, PAUSER_ROLE } = await loadFixture(deployPausableFixture);
      
      expect(await pausable.hasRole(PAUSER_ROLE, admin.address)).to.be.true;
    });
    
    it("Should initialize as not paused", async function () {
      const { pausable } = await loadFixture(deployPausableFixture);
      
      expect(await pausable.paused()).to.be.false;
    });
  });
  
  describe("Pause and Unpause", function () {
    it("Should allow pauser to pause", async function () {
      const { pausable } = await loadFixture(deployPausableFixture);
      
      await pausable.pause();
      expect(await pausable.paused()).to.be.true;
    });
    
    it("Should allow pauser to unpause", async function () {
      const { pausable } = await loadFixture(deployPausableFixture);
      
      await pausable.pause();
      expect(await pausable.paused()).to.be.true;
      
      await pausable.unpause();
      expect(await pausable.paused()).to.be.false;
    });
    
    it("Should prevent non-pausers from pausing", async function () {
      const { pausable, otherAccount } = await loadFixture(deployPausableFixture);
      
      await expect(
        pausable.connect(otherAccount).pause()
      ).to.be.revertedWith("AccessControl: sender doesn't have role");
    });
    
    it("Should prevent non-pausers from unpausing", async function () {
      const { pausable, otherAccount } = await loadFixture(deployPausableFixture);
      
      await pausable.pause();
      
      await expect(
        pausable.connect(otherAccount).unpause()
      ).to.be.revertedWith("AccessControl: sender doesn't have role");
    });
    
    it("Should emit Paused event when pausing", async function () {
      const { pausable, admin } = await loadFixture(deployPausableFixture);
      
      await expect(pausable.pause())
        .to.emit(pausable, "Paused")
        .withArgs(admin.address);
    });
    
    it("Should emit Unpaused event when unpausing", async function () {
      const { pausable, admin } = await loadFixture(deployPausableFixture);
      
      await pausable.pause();
      
      await expect(pausable.unpause())
        .to.emit(pausable, "Unpaused")
        .withArgs(admin.address);
    });
    
    it("Should prevent pausing when already paused", async function () {
      const { pausable } = await loadFixture(deployPausableFixture);
      
      await pausable.pause();
      
      await expect(pausable.pause()).to.be.revertedWith("Pausable: paused");
    });
    
    it("Should prevent unpausing when not paused", async function () {
      const { pausable } = await loadFixture(deployPausableFixture);
      
      await expect(pausable.unpause()).to.be.revertedWith("Pausable: not paused");
    });
  });
});