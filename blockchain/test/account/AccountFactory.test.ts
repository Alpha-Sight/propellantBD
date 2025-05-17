import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { PropellantBDAccount, PropellantBDAccountFactory, RoleModule, UserProfileModule } from "../../typechain-types";
import { IEntryPoint } from "../../typechain-types/contracts/account/EntryPoint";

describe("PropellantBDAccountFactory", function () {
  // Fixture to deploy necessary contracts
  async function deployFactoryFixture() {
    const [deployer, owner1, owner2] = await hre.ethers.getSigners();
    
    // Deploy RoleModule
    const RoleModuleFactory = await hre.ethers.getContractFactory("RoleModule");
    const roleModule = await RoleModuleFactory.deploy();
    
    // Deploy UserProfileModule
    const UserProfileModuleFactory = await hre.ethers.getContractFactory("UserProfileModule");
    const userProfileModule = await UserProfileModuleFactory.deploy(roleModule.target as unknown as string);
    
    // Deploy EntryPoint
    const EntryPointFactory = await hre.ethers.getContractFactory("PropellantBDEntryPoint");
    const entryPoint = await EntryPointFactory.deploy();
    
    // Deploy AccountFactory
    const AccountFactoryF = await hre.ethers.getContractFactory("PropellantBDAccountFactory");
    const accountFactory = await AccountFactoryF.deploy(
      entryPoint.target as unknown as IEntryPoint, 
      userProfileModule.target as unknown as string
    );
    
    // Get role constants
    const ADMIN_ROLE = await roleModule.ADMIN_ROLE();
    const TALENT_ROLE = await roleModule.TALENT_ROLE();
    const ORGANIZATION_ROLE = await roleModule.ORGANIZATION_ROLE();
    
    // Grant roles
    await roleModule.grantRole(ADMIN_ROLE, userProfileModule.target);
    
    return { 
      accountFactory, 
      entryPoint, 
      roleModule, 
      userProfileModule, 
      deployer, 
      owner1, 
      owner2,
      ADMIN_ROLE,
      TALENT_ROLE,
      ORGANIZATION_ROLE
    };
  }
  
  describe("Deployment", function () {
    it("Should deploy with correct parameters", async function () {
      const { accountFactory, entryPoint, userProfileModule } = await loadFixture(deployFactoryFixture);
      
      expect(accountFactory.target).to.not.equal(hre.ethers.ZeroAddress);
      expect(await accountFactory.entryPoint()).to.equal(entryPoint.target);
      expect(await accountFactory.profileModule()).to.equal(userProfileModule.target);
    });
  });
  
  describe("Account Creation", function () {
    it("Should create a new account", async function () {
      const { accountFactory, owner1 } = await loadFixture(deployFactoryFixture);
      
      const salt = 0;
      const expectedAddr = await accountFactory.getAccountAddress(owner1.address, salt);
      
      await expect(accountFactory.createAccount(owner1.address, salt))
        .to.emit(accountFactory, "AccountCreated")
        .withArgs(expectedAddr, owner1.address);
      
      expect(await accountFactory.getAccount(owner1.address)).to.equal(expectedAddr);
    });
    
    it("Should return the same account on second creation", async function () {
      const { accountFactory, owner1 } = await loadFixture(deployFactoryFixture);
      
      const salt = 0;
      await accountFactory.createAccount(owner1.address, salt);
      const account1 = await accountFactory.getAccount(owner1.address);
      
      await accountFactory.createAccount(owner1.address, salt);
      const account2 = await accountFactory.getAccount(owner1.address);
      
      expect(account1).to.equal(account2);
    });
    
    it("Should create different accounts with different salts", async function () {
      const { accountFactory, owner1 } = await loadFixture(deployFactoryFixture);
      
      await accountFactory.createAccount(owner1.address, 0);
      const account1 = await accountFactory.getAccount(owner1.address);
      
      const tx = await accountFactory.createAccount(owner1.address, 1);
      const receipt = await tx.wait();
      
      // Get the created account address from the event
      const event = receipt?.logs.find(log => 
        log.fragment && log.fragment.name === "AccountCreated"
      );
      const account2 = event?.args[0];
      
      expect(account1).to.not.equal(account2);
    });
    
    it("Should create account with profile", async function () {
      const { accountFactory, owner1, userProfileModule } = await loadFixture(deployFactoryFixture);
      
      const salt = 0;
      const name = "Test User";
      const bio = "Test Bio";
      const email = "test@example.com";
      const avatar = "ipfs://QmHash";
      
      const expectedAddr = await accountFactory.getAccountAddress(owner1.address, salt);
      
      await expect(
        accountFactory.createAccountWithProfile(owner1.address, salt, name, bio, email, avatar)
      )
        .to.emit(accountFactory, "AccountInitialized")
        .withArgs(expectedAddr, owner1.address);
      
      // Check that the profile was created
      const profile = await userProfileModule.getProfile(owner1.address);
      expect(profile.name).to.equal(name);
      expect(profile.bio).to.equal(bio);
      expect(profile.email).to.equal(email);
      expect(profile.avatar).to.equal(avatar);
      
      // Check the account was created with the correct parameters
      const accountAddr = await accountFactory.getAccount(owner1.address);
      const account = await hre.ethers.getContractAt("PropellantBDAccount", accountAddr);
      expect(await account.owner()).to.equal(owner1.address);
    });
  });
  
  describe("Counterfactual Deployment", function () {
    it("Should correctly predict account address", async function () {
      const { accountFactory, owner1 } = await loadFixture(deployFactoryFixture);
      
      const salt = 0;
      const predictedAddr = await accountFactory.getAccountAddress(owner1.address, salt);
      
      await accountFactory.createAccount(owner1.address, salt);
      const accountAddr = await accountFactory.getAccount(owner1.address);
      
      expect(predictedAddr).to.equal(accountAddr);
    });
  });
});