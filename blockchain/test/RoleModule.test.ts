import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { RoleModule } from "../typechain-types";

describe("RoleModule", function () {
  // Fixture to deploy a fresh RoleModule contract for each test
  async function deployRoleModuleFixture() {
    const [admin, talent, organization, otherAccount] = await hre.ethers.getSigners();
    
    const RoleModuleFactory = await hre.ethers.getContractFactory("RoleModule");
    const roleModule = await RoleModuleFactory.deploy();
    
    // Get the role constants
    const ADMIN_ROLE = await roleModule.ADMIN_ROLE();
    const TALENT_ROLE = await roleModule.TALENT_ROLE();
    const ORGANIZATION_ROLE = await roleModule.ORGANIZATION_ROLE();
    
    return { 
      roleModule, 
      admin, 
      talent, 
      organization, 
      otherAccount, 
      ADMIN_ROLE, 
      TALENT_ROLE, 
      ORGANIZATION_ROLE 
    };
  }
  
  describe("Deployment", function () {
    it("Should set the deployer as an admin", async function () {
      const { roleModule, admin, ADMIN_ROLE } = await loadFixture(deployRoleModuleFixture);
      
      expect(await roleModule.hasRole(ADMIN_ROLE, admin.address)).to.be.true;
    });
    
    it("Should initialize role metadata correctly", async function () {
      const { roleModule, ADMIN_ROLE, TALENT_ROLE, ORGANIZATION_ROLE } = 
        await loadFixture(deployRoleModuleFixture);
      
      // Check ADMIN_ROLE metadata
      const adminMetadata = await roleModule.getRoleMetadata(ADMIN_ROLE);
      expect(adminMetadata.name).to.equal("Admin");
      expect(adminMetadata.description).to.equal("Administrative capabilities for platform management");
      expect(adminMetadata.active).to.be.true;
      
      // Check TALENT_ROLE metadata
      const talentMetadata = await roleModule.getRoleMetadata(TALENT_ROLE);
      expect(talentMetadata.name).to.equal("Talent");
      expect(talentMetadata.description).to.equal("Users providing services and creating profiles");
      expect(talentMetadata.active).to.be.true;
      
      // Check ORGANIZATION_ROLE metadata
      const orgMetadata = await roleModule.getRoleMetadata(ORGANIZATION_ROLE);
      expect(orgMetadata.name).to.equal("Organization");
      expect(orgMetadata.description).to.equal("Entities seeking talent and verifying credentials");
      expect(orgMetadata.active).to.be.true;
    });
  });
  
  describe("Role Assignment", function () {
    it("Should allow admins to grant roles safely", async function () {
      const { roleModule, talent, TALENT_ROLE } = await loadFixture(deployRoleModuleFixture);
      
      await roleModule.grantRoleSafe(TALENT_ROLE, talent.address);
      expect(await roleModule.hasRole(TALENT_ROLE, talent.address)).to.be.true;
    });
    
    it("Should allow admins to revoke roles safely", async function () {
      const { roleModule, talent, TALENT_ROLE } = await loadFixture(deployRoleModuleFixture);
      
      await roleModule.grantRoleSafe(TALENT_ROLE, talent.address);
      expect(await roleModule.hasRole(TALENT_ROLE, talent.address)).to.be.true;
      
      await roleModule.revokeRoleSafe(TALENT_ROLE, talent.address);
      expect(await roleModule.hasRole(TALENT_ROLE, talent.address)).to.be.false;
    });
    
    it("Should track if an account has any role", async function () {
      const { roleModule, talent, organization, TALENT_ROLE, ORGANIZATION_ROLE } = 
        await loadFixture(deployRoleModuleFixture);
      
      // Initially no roles
      expect(await roleModule.hasAnyRole(talent.address)).to.be.false;
      
      // After granting a role
      await roleModule.grantRoleSafe(TALENT_ROLE, talent.address);
      expect(await roleModule.hasAnyRole(talent.address)).to.be.true;
      
      // After granting multiple roles
      await roleModule.grantRoleSafe(ORGANIZATION_ROLE, talent.address);
      expect(await roleModule.hasAnyRole(talent.address)).to.be.true;
      
      // After revoking one role
      await roleModule.revokeRoleSafe(TALENT_ROLE, talent.address);
      expect(await roleModule.hasAnyRole(talent.address)).to.be.true;
      
      // After revoking all roles
      await roleModule.revokeRoleSafe(ORGANIZATION_ROLE, talent.address);
      expect(await roleModule.hasAnyRole(talent.address)).to.be.false;
    });
    
    it("Should prevent granting inactive roles", async function () {
      const { roleModule, talent, TALENT_ROLE } = await loadFixture(deployRoleModuleFixture);
      
      // Deactivate the role
      await roleModule.updateRoleMetadata(TALENT_ROLE, "Talent", "Deactivated role", false);
      
      await expect(
        roleModule.grantRoleSafe(TALENT_ROLE, talent.address)
      ).to.be.revertedWith("RoleModule: role is not active");
    });
  });
  
  describe("Role Metadata Management", function () {
    it("Should allow admins to update role metadata", async function () {
      const { roleModule, TALENT_ROLE } = await loadFixture(deployRoleModuleFixture);
      
      const newName = "Super Talent";
      const newDescription = "Updated description";
      
      await roleModule.updateRoleMetadata(TALENT_ROLE, newName, newDescription, true);
      
      const metadata = await roleModule.getRoleMetadata(TALENT_ROLE);
      expect(metadata.name).to.equal(newName);
      expect(metadata.description).to.equal(newDescription);
    });
    
    it("Should emit events when updating role metadata", async function () {
      const { roleModule, TALENT_ROLE } = await loadFixture(deployRoleModuleFixture);
      
      const newName = "Updated Talent";
      const newDescription = "New description";
      
      await expect(roleModule.updateRoleMetadata(TALENT_ROLE, newName, newDescription, true))
        .to.emit(roleModule, "RoleMetadataUpdated")
        .withArgs(TALENT_ROLE, newName, newDescription);
    });
    
    it("Should emit events when changing role status", async function () {
      const { roleModule, TALENT_ROLE } = await loadFixture(deployRoleModuleFixture);
      
      // Deactivate the role
      await expect(roleModule.updateRoleMetadata(TALENT_ROLE, "Talent", "Description", false))
        .to.emit(roleModule, "RoleStatusChanged")
        .withArgs(TALENT_ROLE, false);
      
      // Reactivate the role
      await expect(roleModule.updateRoleMetadata(TALENT_ROLE, "Talent", "Description", true))
        .to.emit(roleModule, "RoleStatusChanged")
        .withArgs(TALENT_ROLE, true);
    });
  });
  
  describe("Pausability", function () {
    it("Should prevent role operations when paused", async function () {
      const { roleModule, talent, TALENT_ROLE, PAUSER_ROLE } = await loadFixture(deployRoleModuleFixture);
      
      // Pause the contract
      await roleModule.pause();
      
      await expect(
        roleModule.grantRoleSafe(TALENT_ROLE, talent.address)
      ).to.be.revertedWith("Pausable: paused");
      
      await expect(
        roleModule.updateRoleMetadata(TALENT_ROLE, "Talent", "Description", true)
      ).to.be.revertedWith("Pausable: paused");
    });
  });
});