import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

// --- CONFIGURATION ---
// 1. UPDATE with your relayer's public address
const RELAYER_ADDRESS = "0x2Ed32Af34d80ADB200592e7e0bD6a3F761677591"; 

// 2. UPDATE with the correct path to your deployment file
const deploymentPath = path.join(__dirname, "../deployed-lisk-testnet.json"); 
// ---------------------


async function main() {
  if (!ethers.isAddress(RELAYER_ADDRESS)) {
    console.error("Error: Invalid RELAYER_ADDRESS. Please update the script.");
    process.exit(1);
  }

  console.log("Starting role grant process...");
  const [deployer] = await ethers.getSigners();
  console.log(`Using admin account: ${deployer.address}`);

  // Load deployed contract addresses
  if (!fs.existsSync(deploymentPath)) {
    console.error(`Error: Deployment file not found at ${deploymentPath}`);
    process.exit(1);
  }
  const deployedAddresses = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
  const credentialModuleAddress = deployedAddresses.credentialVerificationModule;

  if (!credentialModuleAddress) {
    console.error("Error: credentialVerificationModule address not found in deployment file.");
    process.exit(1);
  }

  console.log(`Connecting to CredentialVerificationModule at: ${credentialModuleAddress}`);

  // Connect to the deployed CredentialVerificationModule contract
  const credentialVerificationModule = await ethers.getContractAt(
    "CredentialVerificationModule",
    credentialModuleAddress
  );

  // Grant the ISSUER_ROLE to the relayer
  console.log(`\nGranting ISSUER_ROLE to relayer: ${RELAYER_ADDRESS}`);
  
  try {
    const tx = await credentialVerificationModule.connect(deployer).addIssuer(RELAYER_ADDRESS);
    console.log("Transaction sent, waiting for confirmation...");
    await tx.wait();
    console.log("Transaction confirmed:", tx.hash);
    
    // Verify the role was granted
    const hasRole = await credentialVerificationModule.hasRole(
      await credentialVerificationModule.ISSUER_ROLE(),
      RELAYER_ADDRESS
    );

    if (hasRole) {
      console.log(`\n✅ Success! Relayer ${RELAYER_ADDRESS} now has the ISSUER_ROLE.`);
    } else {
      console.error("\n❌ Error: Role grant failed. Please check transaction and contract state.");
    }

  } catch (error) {
    if (error instanceof Error) {
      console.error("\nAn error occurred during the transaction:", error.message);
    } else {
      console.error("\nAn unknown error occurred during the transaction:", error);
    }
    console.error("Please ensure the admin account has the DEFAULT_ADMIN_ROLE and sufficient funds.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });