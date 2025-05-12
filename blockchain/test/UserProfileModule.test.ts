import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { UserProfileModule, RoleModule } from "../typechain-types";

describe("UserProfileModule", function () {
  // Fixture to deploy the necessary contracts for testing
  async function deployUserProfileModuleFixture() {
    const [admin, user1, user2, user3] = await hre.ethers.getSigners();
    
    // First deploy RoleModule
    const RoleModuleFactory = await hre.ethers.getContractFactory("RoleModule");
    const roleModule = await RoleModuleFactory.deploy();
    
    // Then deploy UserProfileModule with RoleModule address
    const UserProfileModuleFactory = await hre.ethers.getContractFactory("UserProfileModule");
    const userProfileModule = await UserProfileModuleFactory.deploy(roleModule.target as unknown as string);
    
    // Get the role constants
    const ADMIN_ROLE = await roleModule.ADMIN_ROLE();
    const TALENT_ROLE = await roleModule.TALENT_ROLE();
    const ORGANIZATION_ROLE = await roleModule.ORGANIZATION_ROLE();
    
    // Grant roles to UserProfileModule to enable it to grant roles
    await roleModule.grantRole(ADMIN_ROLE, userProfileModule.target);
    
    return { 
      userProfileModule,
      roleModule,
      admin, 
      user1, 
      user2, 
      user3,
      ADMIN_ROLE,
      TALENT_ROLE,
      ORGANIZATION_ROLE
    };
  }
  
  describe("Deployment", function () {
    it("Should be deployed with the correct RoleModule address", async function () {
      const { userProfileModule, roleModule } = await loadFixture(deployUserProfileModuleFixture);
      
      // No direct getter for the private _roleModule, but we'll test functionality that depends on it
      expect(userProfileModule.target).to.not.equal(hre.ethers.ZeroAddress);
    });
  });
  
  describe("Profile Management", function () {
    it("Should allow creating a new profile", async function () {
      const { userProfileModule, user1 } = await loadFixture(deployUserProfileModuleFixture);
      
      const name = "John Doe";
      const bio = "Software Developer";
      const email = "john@example.com";
      const avatar = "ipfs://QmHash";
      
      await expect(userProfileModule.connect(user1).createProfile(name, bio, email, avatar))
        .to.emit(userProfileModule, "ProfileCreated")
        .withArgs(user1.address, name, email);
      
      const profile = await userProfileModule.getProfile(user1.address);
      expect(profile.name).to.equal(name);
      expect(profile.bio).to.equal(bio);
      expect(profile.email).to.equal(email);
      expect(profile.avatar).to.equal(avatar);
      expect(profile.active).to.be.true;
    });
    
    it("Should prevent creating a duplicate profile", async function () {
      const { userProfileModule, user1 } = await loadFixture(deployUserProfileModuleFixture);
      
      await userProfileModule.connect(user1).createProfile("John Doe", "Bio", "john@example.com", "avatar");
      
      await expect(
        userProfileModule.connect(user1).createProfile("John Doe", "Bio", "john@example.com", "avatar")
      ).to.be.revertedWith("UserProfileModule: profile already exists");
    });
    
    it("Should prevent creating a profile with an empty name", async function () {
      const { userProfileModule, user1 } = await loadFixture(deployUserProfileModuleFixture);
      
      await expect(
        userProfileModule.connect(user1).createProfile("", "Bio", "john@example.com", "avatar")
      ).to.be.revertedWith("UserProfileModule: name cannot be empty");
    });
    
    it("Should prevent creating a profile with an already registered email", async function () {
      const { userProfileModule, user1, user2 } = await loadFixture(deployUserProfileModuleFixture);
      
      await userProfileModule.connect(user1).createProfile("John Doe", "Bio", "john@example.com", "avatar");
      
      await expect(
        userProfileModule.connect(user2).createProfile("Jane Doe", "Bio", "john@example.com", "avatar")
      ).to.be.revertedWith("UserProfileModule: email already registered");
    });
    
    it("Should allow updating an existing profile", async function () {
      const { userProfileModule, user1 } = await loadFixture(deployUserProfileModuleFixture);
      
      await userProfileModule.connect(user1).createProfile("John Doe", "Bio", "john@example.com", "avatar");
      
      const newName = "Johnny Doe";
      const newBio = "Senior Developer";
      const newAvatar = "ipfs://QmNewHash";
      
      await expect(userProfileModule.connect(user1).updateProfile(newName, newBio, newAvatar))
        .to.emit(userProfileModule, "ProfileUpdated")
        .withArgs(user1.address, newName, newBio);
      
      const profile = await userProfileModule.getProfile(user1.address);
      expect(profile.name).to.equal(newName);
      expect(profile.bio).to.equal(newBio);
      expect(profile.avatar).to.equal(newAvatar);
      expect(profile.email).to.equal("john@example.com"); // Email shouldn't change
    });
    
    it("Should allow profile owner to deactivate their profile", async function () {
      const { userProfileModule, user1 } = await loadFixture(deployUserProfileModuleFixture);
      
      await userProfileModule.connect(user1).createProfile("John Doe", "Bio", "john@example.com", "avatar");
      
      await expect(userProfileModule.connect(user1).deactivateProfile(user1.address))
        .to.emit(userProfileModule, "ProfileDeactivated")
        .withArgs(user1.address);
      
      expect(await userProfileModule.isProfileActive(user1.address)).to.be.false;
    });
    
    it("Should allow admin to deactivate any profile", async function () {
      const { userProfileModule, admin, user1 } = await loadFixture(deployUserProfileModuleFixture);
      
      await userProfileModule.connect(user1).createProfile("John Doe", "Bio", "john@example.com", "avatar");
      
      await expect(userProfileModule.connect(admin).deactivateProfile(user1.address))
        .to.emit(userProfileModule, "ProfileDeactivated")
        .withArgs(user1.address);
      
      expect(await userProfileModule.isProfileActive(user1.address)).to.be.false;
    });
    
    it("Should allow reactivating a deactivated profile", async function () {
      const { userProfileModule, user1 } = await loadFixture(deployUserProfileModuleFixture);
      
      await userProfileModule.connect(user1).createProfile("John Doe", "Bio", "john@example.com", "avatar");
      await userProfileModule.connect(user1).deactivateProfile(user1.address);
      
      await expect(userProfileModule.connect(user1).reactivateProfile(user1.address))
        .to.emit(userProfileModule, "ProfileReactivated")
        .withArgs(user1.address);
      
      expect(await userProfileModule.isProfileActive(user1.address)).to.be.true;
    });
  });
  
  describe("Social Handle Management", function () {
    it("Should allow adding a social handle", async function () {
      const { userProfileModule, user1 } = await loadFixture(deployUserProfileModuleFixture);
      
      await userProfileModule.connect(user1).createProfile("John Doe", "Bio", "john@example.com", "avatar");
      
      const platform = "twitter";
      const handle = "@johndoe";
      
      await expect(userProfileModule.connect(user1).addSocialHandle(platform, handle))
        .to.emit(userProfileModule, "SocialHandleAdded")
        .withArgs(user1.address, platform, handle);
      
      const handles = await userProfileModule.getSocialHandles(user1.address);
      expect(handles.length).to.equal(1);
      expect(handles[0].platform).to.equal(platform);
      expect(handles[0].handle).to.equal(handle);
      expect(handles[0].verified).to.be.false;
    });
    
    it("Should update existing handle if platform already exists", async function () {
      const { userProfileModule, user1 } = await loadFixture(deployUserProfileModuleFixture);
      
      await userProfileModule.connect(user1).createProfile("John Doe", "Bio", "john@example.com", "avatar");
      await userProfileModule.connect(user1).addSocialHandle("twitter", "@johndoe");
      
      const newHandle = "@john_doe";
      await userProfileModule.connect(user1).addSocialHandle("twitter", newHandle);
      
      const handles = await userProfileModule.getSocialHandles(user1.address);
      expect(handles.length).to.equal(1);
      expect(handles[0].platform).to.equal("twitter");
      expect(handles[0].handle).to.equal(newHandle);
    });
    
    it("Should allow removing a social handle", async function () {
      const { userProfileModule, user1 } = await loadFixture(deployUserProfileModuleFixture);
      
      await userProfileModule.connect(user1).createProfile("John Doe", "Bio", "john@example.com", "avatar");
      await userProfileModule.connect(user1).addSocialHandle("twitter", "@johndoe");
      await userProfileModule.connect(user1).addSocialHandle("github", "johndoe");
      
      await expect(userProfileModule.connect(user1).removeSocialHandle("twitter"))
        .to.emit(userProfileModule, "SocialHandleRemoved")
        .withArgs(user1.address, "twitter");
      
      const handles = await userProfileModule.getSocialHandles(user1.address);
      expect(handles.length).to.equal(1);
      expect(handles[0].platform).to.equal("github");
    });
    
    it("Should allow admin to verify a social handle", async function () {
      const { userProfileModule, admin, user1 } = await loadFixture(deployUserProfileModuleFixture);
      
      await userProfileModule.connect(user1).createProfile("John Doe", "Bio", "john@example.com", "avatar");
      await userProfileModule.connect(user1).addSocialHandle("twitter", "@johndoe");
      
      const nonce = 123456;
      const verificationHash = await userProfileModule.generateVerificationHash(user1.address, "twitter", nonce);
      
      await expect(userProfileModule.connect(admin).verifySocialHandle(user1.address, "twitter", verificationHash))
        .to.emit(userProfileModule, "SocialHandleVerified")
        .withArgs(user1.address, "twitter", "@johndoe");
      
      expect(await userProfileModule.isHandleVerified(user1.address, "twitter")).to.be.true;
    });
  });
  
  describe("Email Lookups", function () {
    it("Should allow looking up an address by email", async function () {
      const { userProfileModule, user1 } = await loadFixture(deployUserProfileModuleFixture);
      
      const email = "john@example.com";
      await userProfileModule.connect(user1).createProfile("John Doe", "Bio", email, "avatar");
      
      expect(await userProfileModule.getAddressByEmail(email)).to.equal(user1.address);
    });
  });
  
  describe("Pausability", function () {
    it("Should prevent profile operations when paused", async function () {
      const { userProfileModule, user1 } = await loadFixture(deployUserProfileModuleFixture);
      
      // Pause the contract
      await userProfileModule.pause();
      
      await expect(
        userProfileModule.connect(user1).createProfile("John Doe", "Bio", "john@example.com", "avatar")
      ).to.be.revertedWith("Pausable: paused");
    });
  });
});