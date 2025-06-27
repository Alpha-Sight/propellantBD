import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

// Import the ABI directly from the compiled artifact
import CredentialModuleArtifact from "../artifacts/contracts/modules/CredentialVerificationModule.sol/CredentialVerificationModule.json";

async function main() {
  // --- CONFIGURATION ---
  const RELAYER_ADDRESS = "0x2Ed32Af34d80ADB200592e7e0bD6a3F761677591"; 
  const deploymentPath = path.join(__dirname, "../deployed-lisk-testnet.json"); 
  // ---------------------

  console.log("🚀 [Direct Grant] Starting role grant process...");
  const [adminSigner] = await ethers.getSigners();
  console.log(`Using admin account: ${adminSigner.address}`);

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

  // Create a contract instance manually using the raw ABI and connect the signer
  const credentialModule = new ethers.Contract(
    credentialModuleAddress,
    CredentialModuleArtifact.abi,
    adminSigner 
  );

  console.log(`\nGranting ISSUER_ROLE to relayer: ${RELAYER_ADDRESS}`);
  
  try {
    // Call the addIssuer function on the manually created contract instance
    const tx = await credentialModule.addIssuer(RELAYER_ADDRESS);
    
    console.log("Transaction sent, waiting for confirmation...");
    console.log("Tx Hash:", tx.hash);
    await tx.wait();
    console.log("Transaction confirmed!");
    
    // Verify the role was granted using the ISSUER_ROLE hash
    const ISSUER_ROLE = await credentialModule.ISSUER_ROLE();
    const hasRole = await credentialModule.hasRole(
      ISSUER_ROLE,
      RELAYER_ADDRESS
    );

    if (hasRole) {
      console.log(`\n✅ Success! Relayer ${RELAYER_ADDRESS} now has the ISSUER_ROLE.`);
      console.log("You can now restart your backend and try minting a credential.");
    } else {
      console.error("\n❌ Error: Role grant failed even after transaction confirmation. Please check the contract state on the block explorer.");
    }

  } catch (error: unknown) {
    console.error("\n❌ An error occurred during the transaction:", 
      error instanceof Error ? error.message : String(error));
    
    // Check if error is an object with a data property
    if (error && typeof error === 'object' && 'data' in error) {
      console.error("Error data:", (error as { data: unknown }).data);
    }
    console.error("\nIf this fails, the contract's on-chain state is inconsistent. Redeploying the contracts is the recommended next step.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });