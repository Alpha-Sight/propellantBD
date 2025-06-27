import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  console.log("🔍 Checking contract admin roles...");

  // --- CONFIGURATION ---
  const deploymentPath = path.join(__dirname, "../deployed-lisk-testnet.json");
  // ---------------------

  const [signer] = await ethers.getSigners();
  console.log(`Using account: ${signer.address}`);

  // Load deployed contract addresses
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

  // Connect to the contract
  const credentialModule = await ethers.getContractAt(
    "CredentialVerificationModule",
    credentialModuleAddress
  );

  try {
    // The DEFAULT_ADMIN_ROLE is always bytes32(0)
    const ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";
    console.log(`DEFAULT_ADMIN_ROLE hash: ${ADMIN_ROLE}`);

    // Find out how many members have the admin role
    const adminCount = await credentialModule.getRoleMemberCount(ADMIN_ROLE);
    console.log(`Number of admins: ${adminCount.toString()}`);

    if (adminCount === 0n) { // Use BigInt for comparison
      console.error("\n❌ Critical Error: There are no accounts with the DEFAULT_ADMIN_ROLE.");
      console.error("The admin role may have been renounced. The contract might need to be redeployed.");
      process.exit(1);
    }

    // Get the address of the first admin
    const adminAddress = await credentialModule.getRoleMember(ADMIN_ROLE, 0);
    console.log(`\n✅ The current contract admin is: ${adminAddress}`);

    // Check if the current signer is the admin
    if (ethers.getAddress(adminAddress) === ethers.getAddress(signer.address)) {
      console.log("✅ The account in your .env file IS the contract admin.");
      console.log("The previous error was likely due to a compilation issue. Please try the 'grant-issuer-role.ts' script again.");
    } else {
      console.error("\n❌ Mismatch Found!");
      console.error(`The account in your .env file (${signer.address}) is NOT the contract admin.`);
      console.error("To grant roles, you must run the script using the private key of the admin account listed above.");
    }
  } catch (error) {
    console.error("\nAn error occurred while checking roles:", error);
    console.error("This might be due to outdated contract artifacts. Please try cleaning and recompiling your project as instructed.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });