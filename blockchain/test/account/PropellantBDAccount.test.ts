import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { PropellantBDAccount, RoleModule, UserProfileModule } from "../../typechain-types";
import { IEntryPoint } from "../../typechain-types/contracts/account/EntryPoint";

describe("PropellantBDAccount", function () {
  // Fixture to deploy necessary contracts
  async function deployAccountFixture() {
    const [deployer, owner, user1] = await hre.ethers.getSigners();
    
    // Deploy RoleModule
    const RoleModuleFactory = await hre.ethers.getContractFactory("RoleModule");
    const roleModule = await RoleModuleFactory.deploy();
    
    // Deploy UserProfileModule
    const UserProfileModuleFactory = await hre.ethers.getContractFactory("UserProfileModule");
    const userProfileModule = await UserProfileModuleFactory.deploy(roleModule.target as unknown as string);
    
    // Deploy EntryPoint
    const EntryPointFactory = await hre.ethers.getContractFactory("PropellantBDEntryPoint");
    const entryPoint = await EntryPointFactory.deploy();
    
    // Deploy Account
    const AccountFactory = await hre.ethers.getContractFactory("PropellantBDAccount");
    const account = await AccountFactory.deploy(
      entryPoint.target as unknown as IEntryPoint, 
      userProfileModule.target as unknown as string
    );
    
    // Initialize the account
    await account.initialize(owner.address);
    
    // Get role constants
    const ADMIN_ROLE = await roleModule.ADMIN_ROLE();
    const TALENT_ROLE = await roleModule.TALENT_ROLE();
    const ORGANIZATION_ROLE = await roleModule.ORGANIZATION_ROLE();
    
    // Grant roles
    await roleModule.grantRole(ADMIN_ROLE, userProfileModule.target);
    
    return { 
      account, 
      entryPoint, 
      roleModule, 
      userProfileModule, 
      deployer, 
      owner, 
      user1,
      ADMIN_ROLE,
      TALENT_ROLE,
      ORGANIZATION_ROLE
    };
  }
  
  describe("Deployment", function () {
    it("Should deploy with correct parameters", async function () {
      const { account, userProfileModule, owner } = await loadFixture(deployAccountFixture);
      
      expect(account.target).to.not.equal(hre.ethers.ZeroAddress);
      expect(await account.owner()).to.equal(owner.address);
      expect(await account.profileModule()).to.equal(userProfileModule.target);
    });
  });
  
  describe("Profile Integration", function () {
    it("Should allow initializing with a profile", async function () {
      const { account, owner, userProfileModule } = await loadFixture(deployAccountFixture);
      
      const name = "Test User";
      const bio = "A test user profile";
      const email = "test@example.com";
      const avatar = "ipfs://QmHash";
      
      await expect(account.connect(owner).initializeWithProfile(name, bio, email, avatar))
        .to.emit(account, "ProfileLinked")
        .withArgs(account.target, owner.address);
      
      expect(await account.hasProfile()).to.be.true;
      
      // Check profile was created in the UserProfileModule
      const profile = await userProfileModule.getProfile(owner.address);
      expect(profile.name).to.equal(name);
      expect(profile.bio).to.equal(bio);
      expect(profile.email).to.equal(email);
      expect(profile.avatar).to.equal(avatar);
    });
    
    it("Should prevent non-owners from initializing profile", async function () {
      const { account, user1 } = await loadFixture(deployAccountFixture);
      
      await expect(
        account.connect(user1).initializeWithProfile("Name", "Bio", "email@example.com", "avatar")
      ).to.be.revertedWith("Sender not an owner");
    });
    
    it("Should prevent initializing profile twice", async function () {
      const { account, owner } = await loadFixture(deployAccountFixture);
      
      // Initialize first time
      await account.connect(owner).initializeWithProfile(
        "Test User", "Bio", "test@example.com", "avatar"
      );
      
      // Try to initialize again
      await expect(
        account.connect(owner).initializeWithProfile(
          "New Name", "New Bio", "new@example.com", "newavatar"
        )
      ).to.be.revertedWith("PropellantBDAccount: profile already initialized");
    });
    
    it("Should allow updating an existing profile", async function () {
      const { account, owner, userProfileModule } = await loadFixture(deployAccountFixture);
      
      // Initialize profile
      await account.connect(owner).initializeWithProfile(
        "Test User", "Bio", "test@example.com", "avatar"
      );
      
      // Update profile
      const newName = "Updated User";
      const newBio = "Updated Bio";
      const newAvatar = "ipfs://QmNewHash";
      
      await account.connect(owner).updateProfile(newName, newBio, newAvatar);
      
      // Check profile was updated
      const profile = await userProfileModule.getProfile(owner.address);
      expect(profile.name).to.equal(newName);
      expect(profile.bio).to.equal(newBio);
      expect(profile.avatar).to.equal(newAvatar);
    });
    
    it("Should allow adding social handles", async function () {
      const { account, owner, userProfileModule } = await loadFixture(deployAccountFixture);
      
      // Initialize profile
      await account.connect(owner).initializeWithProfile(
        "Test User", "Bio", "test@example.com", "avatar"
      );
      
      // Add a social handle
      const platform = "twitter";
      const handle = "@testuser";
      
      await account.connect(owner).addSocialHandle(platform, handle);
      
      // Check handle was added
      const handles = await userProfileModule.getSocialHandles(owner.address);
      expect(handles.length).to.equal(1);
      expect(handles[0].platform).to.equal(platform);
      expect(handles[0].handle).to.equal(handle);
    });
    
    it("Should allow removing social handles", async function () {
      const { account, owner, userProfileModule } = await loadFixture(deployAccountFixture);
      
      // Initialize profile
      await account.connect(owner).initializeWithProfile(
        "Test User", "Bio", "test@example.com", "avatar"
      );
      
      // Add social handles
      await account.connect(owner).addSocialHandle("twitter", "@testuser");
      await account.connect(owner).addSocialHandle("github", "testuser");
      
      // Remove one handle
      await account.connect(owner).removeSocialHandle("twitter");
      
      // Check handle was removed
      const handles = await userProfileModule.getSocialHandles(owner.address);
      expect(handles.length).to.equal(1);
      expect(handles[0].platform).to.equal("github");
    });
  });
});