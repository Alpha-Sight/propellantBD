import { ethers } from "hardhat";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";

// Load environment variables
dotenv.config();

// Import the ABI directly from the artifact
import CredentialModuleArtifact from "../artifacts/contracts/modules/CredentialVerificationModule.sol/CredentialVerificationModule.json";

async function main() {
  console.log("🔍 [Direct Check] Checking contract admin roles...");

  // --- CONFIGURATION ---
  const deploymentPath = path.join(__dirname, "../deployed-lisk-testnet.json");
  // ---------------------

  const [signer] = await ethers.getSigners();
  console.log(`Using account: ${signer.address}`);

  // Load deployed contract address
  if (!fs.existsSync(deploymentPath)) {
    console.error(`❌ Error: Deployment file not found at ${deploymentPath}`);
    process.exit(1);
  }
  const deployedAddresses = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
  const credentialModuleAddress = deployedAddresses.credentialVerificationModule;

  if (!credentialModuleAddress) {
    console.error("❌ Error: credentialVerificationModule address not found in deployment file.");
    process.exit(1);
  }

  console.log(`\nConnecting to CredentialVerificationModule at: ${credentialModuleAddress}`);

  // Create a contract instance manually using the ABI
  const credentialModule = new ethers.Contract(
    credentialModuleAddress,
    CredentialModuleArtifact.abi,
    signer
  );

  try {
    const ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";
    console.log(`DEFAULT_ADMIN_ROLE hash: ${ADMIN_ROLE}`);

    // Check if the current signer has admin role
    const hasAdminRole = await credentialModule.hasRole(ADMIN_ROLE, signer.address);
    
    if (hasAdminRole) {
      console.log(`\n✅ The current contract admin is: ${signer.address}`);

      const adminAddress = process.env.ADMIN_ADDRESS;
      if (adminAddress) {
        if (ethers.getAddress(adminAddress) === ethers.getAddress(signer.address)) {
          console.log("✅ The account in your .env file IS the contract admin.");
          console.log("You can now proceed with the 'grant-issuer-role.ts' script.");
        } else {
          console.error("\n❌ Mismatch Found!");
          console.error(`The account in your .env file (${adminAddress}) is NOT the contract admin.`);
        }
      } else {
        console.log("⚠️ No ADMIN_ADDRESS found in .env file. Skipping address comparison check.");
      }
    } else {
      console.error("\n❌ Mismatch Found!");
      console.error(`The account in your .env file (${signer.address}) is NOT the contract admin.`);
    }
  } catch (error) {
    console.error("\n❌ An error occurred during the direct check:", error);
    console.error("\nIf this script fails, it strongly suggests the contract deployed at the target address does not have the AccessControl interface.");
    console.error("The most likely solution is to redeploy the contract.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });