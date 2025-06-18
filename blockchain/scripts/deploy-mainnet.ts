import hre from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  console.log("Deploying contracts to mainnet...");

  // Deploy RoleModule
  const RoleModule = await hre.ethers.getContractFactory("RoleModule");
  const roleModule = await RoleModule.deploy();
  await roleModule.waitForDeployment();
  console.log(`RoleModule deployed to: ${roleModule.target}`);

  // Deploy UserProfileModule
  const UserProfileModule = await hre.ethers.getContractFactory("UserProfileModule");
  const userProfileModule = await UserProfileModule.deploy(roleModule.target);
  await userProfileModule.waitForDeployment();
  console.log(`UserProfileModule deployed to: ${userProfileModule.target}`);

  // Deploy EntryPoint
  const EntryPoint = await hre.ethers.getContractFactory("PropellantBDEntryPoint");
  const entryPoint = await EntryPoint.deploy();
  await entryPoint.waitForDeployment();
  console.log(`EntryPoint deployed to: ${entryPoint.target}`);

  // Deploy AccountFactory
  const AccountFactory = await hre.ethers.getContractFactory("PropellantBDAccountFactory");
  const accountFactory = await AccountFactory.deploy(entryPoint.target, userProfileModule.target);
  await accountFactory.waitForDeployment();
  console.log(`AccountFactory deployed to: ${accountFactory.target}`);

  // Deploy Paymaster
  const Paymaster = await hre.ethers.getContractFactory("PropellantBDPaymaster");
  const paymaster = await Paymaster.deploy(entryPoint.target, userProfileModule.target, roleModule.target, hre.ethers.ZeroAddress);
  await paymaster.waitForDeployment();
  console.log(`Paymaster deployed to: ${paymaster.target}`);

  // Deploy StorageModule
  const StorageModule = await hre.ethers.getContractFactory("StorageModule");
  const storageModule = await StorageModule.deploy(roleModule.target);
  await storageModule.waitForDeployment();
  console.log(`StorageModule deployed to: ${storageModule.target}`);

  // Deploy CredentialVerificationModule
  const CredentialVerificationModule = await hre.ethers.getContractFactory("CredentialVerificationModule");
  const credentialVerificationModule = await CredentialVerificationModule.deploy(
    roleModule.target,
    userProfileModule.target
  );
  await credentialVerificationModule.waitForDeployment();
  console.log(`CredentialVerificationModule deployed to: ${credentialVerificationModule.target}`);

  // Fund the paymaster
  const [deployer] = await hre.ethers.getSigners();
  const fundTx = await deployer.sendTransaction({
    to: paymaster.target,
    value: hre.ethers.parseEther("0.5"), // Fund with 0.5 ETH
  });
  await fundTx.wait();
  console.log(`Funded paymaster with 0.5 ETH`);

  // Save the deployed addresses to a file
  const addresses = {
    roleModule: roleModule.target,
    userProfileModule: userProfileModule.target,
    entryPoint: entryPoint.target,
    accountFactory: accountFactory.target,
    paymaster: paymaster.target,
    storageModule: storageModule.target,
    credentialVerificationModule: credentialVerificationModule.target,
  };

  fs.writeFileSync(
    path.join(__dirname, "../deployed-mainnet.json"),
    JSON.stringify(addresses, null, 2)
  );
  console.log("Deployment addresses saved to deployed-mainnet.json");

  // Create .env file for the backend
  const envContent = `
# Blockchain Configuration for Mainnet
BLOCKCHAIN_RPC_URL=https://mainnet-api.lisk.com
RELAYER_PRIVATE_KEY=PUT_YOUR_PRIVATE_KEY_HERE
ENTRY_POINT_ADDRESS=${entryPoint.target}
ACCOUNT_FACTORY_ADDRESS=${accountFactory.target}
PAYMASTER_ADDRESS=${paymaster.target}
USER_PROFILE_MODULE_ADDRESS=${userProfileModule.target}
CREDENTIAL_VERIFICATION_MODULE_ADDRESS=${credentialVerificationModule.target}
ROLE_MODULE_ADDRESS=${roleModule.target}
`;

  fs.writeFileSync(
    path.join(__dirname, "../mainnet.env"),
    envContent
  );
  console.log("Environment configuration saved to mainnet.env");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});