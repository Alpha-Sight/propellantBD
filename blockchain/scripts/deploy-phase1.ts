import { ethers } from "hardhat";
import { verify } from "./verify";

async function main() {
  console.log("Starting Phase 1 deployment...");
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  // Deploy RoleModule first (it has no dependencies)
  console.log("Deploying RoleModule...");
  const RoleModule = await ethers.getContractFactory("RoleModule");
  const roleModule = await RoleModule.deploy();
  await roleModule.waitForDeployment();
  const roleModuleAddress = await roleModule.getAddress();
  console.log(`RoleModule deployed to: ${roleModuleAddress}`);

  // Deploy UserProfileModule (depends on RoleModule)
  console.log("Deploying UserProfileModule...");
  const UserProfileModule = await ethers.getContractFactory("UserProfileModule");
  const userProfileModule = await UserProfileModule.deploy(roleModuleAddress as unknown as string);
  await userProfileModule.waitForDeployment();
  const userProfileModuleAddress = await userProfileModule.getAddress();
  console.log(`UserProfileModule deployed to: ${userProfileModuleAddress}`);

  // Deploy StorageModule (depends on RoleModule)
  console.log("Deploying StorageModule...");
  const StorageModule = await ethers.getContractFactory("StorageModule");
  const storageModule = await StorageModule.deploy(roleModuleAddress as unknown as string);
  await storageModule.waitForDeployment();
  const storageModuleAddress = await storageModule.getAddress();
  console.log(`StorageModule deployed to: ${storageModuleAddress}`);

  // Deploy CredentialVerificationModule (depends on RoleModule and UserProfileModule)
  console.log("Deploying CredentialVerificationModule...");
  const CredentialVerificationModule = await ethers.getContractFactory("CredentialVerificationModule");
  const credentialVerificationModule = await CredentialVerificationModule.deploy(
    roleModuleAddress as unknown as string,
    userProfileModuleAddress as unknown as string
  );
  await credentialVerificationModule.waitForDeployment();
  const credentialVerificationModuleAddress = await credentialVerificationModule.getAddress();
  console.log(`CredentialVerificationModule deployed to: ${credentialVerificationModuleAddress}`);

  // Setup initial configuration
  console.log("Setting up initial configuration...");

  // Grant ADMIN_ROLE to modules to enable them to interact with RoleModule
  const ADMIN_ROLE = await roleModule.ADMIN_ROLE();
  
  // Grant admin permissions to the modules that need to interact with RoleModule
  await roleModule.grantRole(ADMIN_ROLE, userProfileModuleAddress);
  await roleModule.grantRole(ADMIN_ROLE, credentialVerificationModuleAddress);
  
  console.log("Initial configuration completed!");
  
  // Log all deployment addresses for reference
  console.log("\nDeployment Summary:");
  console.log("-------------------");
  console.log(`RoleModule: ${roleModuleAddress}`);
  console.log(`UserProfileModule: ${userProfileModuleAddress}`);
  console.log(`StorageModule: ${storageModuleAddress}`);
  console.log(`CredentialVerificationModule: ${credentialVerificationModuleAddress}`);

  // Optional: Verify contracts on Etherscan/block explorer
  if (process.env.VERIFY_CONTRACTS === 'true') {
    console.log("\nVerifying contracts...");
    // Add delay to allow blockchain to index the contracts
    await new Promise(resolve => setTimeout(resolve, 60000));
    
    // Verify RoleModule
    await verify(roleModuleAddress, []);
    
    // Verify UserProfileModule
    await verify(userProfileModuleAddress, [roleModuleAddress]);
    
    // Verify StorageModule
    await verify(storageModuleAddress, [roleModuleAddress]);
    
    // Verify CredentialVerificationModule
    await verify(credentialVerificationModuleAddress, [roleModuleAddress, userProfileModuleAddress]);
    
    console.log("Contract verification completed!");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });