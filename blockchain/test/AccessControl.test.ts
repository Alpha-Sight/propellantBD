import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { AccessControl } from "../typechain-types";

describe("AccessControl", function () {
  // Fixture to deploy a fresh AccessControl contract for each test
  async function deployAccessControlFixture() {
    const [admin, otherAccount, thirdAccount] = await hre.ethers.getSigners();
    
    const AccessControlFactory = await hre.ethers.getContractFactory("AccessControl");
    const accessControl = await AccessControlFactory.deploy();
    
    // Define a test role
    const TEST_ROLE = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("TEST_ROLE"));
    
    return { accessControl, admin, otherAccount, thirdAccount, TEST_ROLE };
  }
  
  describe("Deployment", function () {
    it("Should set the deployer as the default admin", async function () {
      const { accessControl, admin } = await loadFixture(deployAccessControlFixture);
      
      const DEFAULT_ADMIN_ROLE = await accessControl.DEFAULT_ADMIN_ROLE();
      expect(await accessControl.hasRole(DEFAULT_ADMIN_ROLE, admin.address)).to.be.true;
    });
  });
  
  describe("Role Management", function () {
    it("Should allow admin to grant roles", async function () {
      const { accessControl, otherAccount, TEST_ROLE } = await loadFixture(deployAccessControlFixture);
      
      await accessControl.grantRole(TEST_ROLE, otherAccount.address);
      expect(await accessControl.hasRole(TEST_ROLE, otherAccount.address)).to.be.true;
    });
    
    it("Should allow admin to revoke roles", async function () {
      const { accessControl, otherAccount, TEST_ROLE } = await loadFixture(deployAccessControlFixture);
      
      await accessControl.grantRole(TEST_ROLE, otherAccount.address);
      expect(await accessControl.hasRole(TEST_ROLE, otherAccount.address)).to.be.true;
      
      await accessControl.revokeRole(TEST_ROLE, otherAccount.address);
      expect(await accessControl.hasRole(TEST_ROLE, otherAccount.address)).to.be.false;
    });
    
    it("Should allow accounts to renounce their roles", async function () {
      const { accessControl, admin, otherAccount, TEST_ROLE } = await loadFixture(deployAccessControlFixture);
      
      await accessControl.grantRole(TEST_ROLE, otherAccount.address);
      expect(await accessControl.hasRole(TEST_ROLE, otherAccount.address)).to.be.true;
      
      await accessControl.connect(otherAccount).renounceRole(TEST_ROLE);
      expect(await accessControl.hasRole(TEST_ROLE, otherAccount.address)).to.be.false;
    });
    
    it("Should prevent non-admins from granting roles", async function () {
      const { accessControl, otherAccount, thirdAccount, TEST_ROLE } = await loadFixture(deployAccessControlFixture);
      
      await expect(
        accessControl.connect(otherAccount).grantRole(TEST_ROLE, thirdAccount.address)
      ).to.be.revertedWith("AccessControl: sender doesn't have role");
    });
    
    it("Should prevent non-admins from revoking roles", async function () {
      const { accessControl, admin, otherAccount, thirdAccount, TEST_ROLE } = await loadFixture(deployAccessControlFixture);
      
      await accessControl.grantRole(TEST_ROLE, thirdAccount.address);
      
      await expect(
        accessControl.connect(otherAccount).revokeRole(TEST_ROLE, thirdAccount.address)
      ).to.be.revertedWith("AccessControl: sender doesn't have role");
    });
    
    it("Should emit RoleGranted event when granting a role", async function () {
      const { accessControl, admin, otherAccount, TEST_ROLE } = await loadFixture(deployAccessControlFixture);
      
      await expect(accessControl.grantRole(TEST_ROLE, otherAccount.address))
        .to.emit(accessControl, "RoleGranted")
        .withArgs(TEST_ROLE, otherAccount.address, admin.address);
    });
    
    it("Should emit RoleRevoked event when revoking a role", async function () {
      const { accessControl, admin, otherAccount, TEST_ROLE } = await loadFixture(deployAccessControlFixture);
      
      await accessControl.grantRole(TEST_ROLE, otherAccount.address);
      
      await expect(accessControl.revokeRole(TEST_ROLE, otherAccount.address))
        .to.emit(accessControl, "RoleRevoked")
        .withArgs(TEST_ROLE, otherAccount.address, admin.address);
    });
  });
});