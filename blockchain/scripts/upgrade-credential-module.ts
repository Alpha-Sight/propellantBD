import { ethers } from "hardhat";

async function main() {
  console.log("Deploying CredentialVerificationModule implementation...");
  
  // Get necessary addresses from your deployment
  const roleModuleAddress = "0x597c42D3E14E04e1FE39ECd0c4f7Ba56060a0B51";
  const userProfileModuleAddress = "0x05fAE0FAA9bDece71ccDf4Ce351A85f86c5967aA";
  const proxyAddress = "0x97EFAC0f624dD45ffBCF80e1779618d89104eF6C";
  
  // Deploy the implementation
  console.log("Deploying implementation contract...");
  const CredentialVerificationModule = await ethers.getContractFactory("CredentialVerificationModule");
  const implementation = await CredentialVerificationModule.deploy(roleModuleAddress, userProfileModuleAddress);
  await implementation.waitForDeployment();
  const implementationAddress = await implementation.getAddress();
  console.log(`Implementation deployed to: ${implementationAddress}`);
  
  // Connect to the proxy using your Upgradeable contract, not IUpgradeableProxy
  console.log("Connecting to proxy contract...");
  const proxy = await ethers.getContractAt("Upgradeable", proxyAddress);
  
  // Get deployer (signer)
  const [deployer] = await ethers.getSigners();
  console.log(`Setting implementation using address: ${deployer.address}`);
  
  // Set implementation
  console.log("Setting implementation...");
const tx = await proxy.upgradeTo(implementationAddress);
  await tx.wait();
  
  console.log(`Implementation set successfully: ${implementationAddress}`);
  
  // Verify that it worked by creating a properly connected contract instance
  console.log("Verifying implementation is set correctly...");
  const credentialModule = await ethers.getContractAt("CredentialVerificationModule", proxyAddress);
  
  try {
    // Try to call a view function to verify the contract works
    const issuerRole = await credentialModule.ISSUER_ROLE();
    console.log(`Contract is working! ISSUER_ROLE: ${issuerRole}`);
  } catch (error) {
    console.error("Error when calling contract method:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });