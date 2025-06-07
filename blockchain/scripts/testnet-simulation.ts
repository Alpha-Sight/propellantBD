import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

// Load deployment addresses
const deploymentPath = path.join(__dirname, "../deployed-lisk-testnet.json");
const deployedAddresses = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));

async function main() {
  console.log("Starting testnet simulation...");
  const [deployer, issuer, talent] = await ethers.getSigners();
  
  console.log(`Using accounts:`);
  console.log(`- Deployer: ${deployer.address}`);
  console.log(`- Issuer: ${issuer.address}`);
  console.log(`- Talent: ${talent.address}`);
  
  // Connect to deployed contracts
  const roleModule = await ethers.getContractAt("RoleModule", deployedAddresses.roleModule);
  const userProfileModule = await ethers.getContractAt("UserProfileModule", deployedAddresses.userProfileModule);
  const credentialNFT = await ethers.getContractAt("CredentialNFT", deployedAddresses.credentialNFT);
  const credentialVerificationModule = await ethers.getContractAt(
    "CredentialVerificationModule", 
    deployedAddresses.credentialVerificationModule
  );
  
  // 1. Setup roles
  console.log("\nSetting up roles...");
  
  const ADMIN_ROLE = await roleModule.ADMIN_ROLE();
  const TALENT_ROLE = await roleModule.TALENT_ROLE();
  const ORGANIZATION_ROLE = await roleModule.ORGANIZATION_ROLE();
  const ISSUER_ROLE = await credentialVerificationModule.ISSUER_ROLE();
  
  // Grant roles
  const tx1 = await roleModule.grantRoleSafe(ORGANIZATION_ROLE, issuer.address);
  await tx1.wait();
  console.log(`Granted ORGANIZATION_ROLE to issuer ${issuer.address}`);
  
  const tx2 = await roleModule.grantRoleSafe(TALENT_ROLE, talent.address);
  await tx2.wait();
  console.log(`Granted TALENT_ROLE to talent ${talent.address}`);
  
  const tx3 = await credentialVerificationModule.addIssuer(issuer.address);
  await tx3.wait();
  console.log(`Added issuer ${issuer.address}`);
  
  // 2. Create profiles
  console.log("\nCreating user profiles...");
  
  // Create issuer profile
  const tx4 = await userProfileModule.connect(issuer).createProfile(
    "Acme Corporation",
    "Leading certification authority",
    "issuer@acme.com",
    "ipfs://QmIssuerAvatar"
  );
  await tx4.wait();
  console.log("Issuer profile created");
  
  // Create talent profile
  const tx5 = await userProfileModule.connect(talent).createProfile(
    "John Doe",
    "Software Engineer",
    "john.doe@example.com",
    "ipfs://QmTalentAvatar"
  );
  await tx5.wait();
  console.log("Talent profile created");
  
  // 3. Issue a credential
  console.log("\nIssuing credential...");
  
  // Create credential metadata
  const metadataJson = JSON.stringify({
    name: "Advanced Software Engineering Certificate",
    description: "Certified expert in software architecture and design patterns",
    issuer: {
      name: "Acme Corporation",
      website: "https://acme.com",
      logo: "ipfs://QmIssuerLogo"
    },
    skills: ["System Design", "Architecture Patterns", "Clean Code"],
    criteria: "Successfully demonstrated advanced software engineering principles",
    evidence: "ipfs://QmEvidenceHash"
  });
  
  // Upload metadata to IPFS (simulated)
  const metadataURI = `ipfs://QmCredentialMetadata${Date.now()}`;
  console.log(`Metadata URI: ${metadataURI}`);
  
  // Evidence hash
  const evidenceHash = ethers.keccak256(ethers.toUtf8Bytes("Exam scores: 95/100, Project: A+"));
  
  // Issue credential through the verification module
  const tx6 = await credentialVerificationModule.connect(issuer).issueCredential(
    talent.address,
    "Advanced Software Engineering Certificate",
    "Certified expert in software architecture and design patterns",
    metadataURI,
    1, // CERTIFICATION type
    0, // No expiration
    evidenceHash
  );
  const receipt6 = await tx6.wait();
  
  // Extract credential ID from event
  const event = receipt6?.logs.find(log => 
    log.fragment && log.fragment.name === "CredentialSubmitted"
  );
  const credentialId = event?.args[0];
  console.log(`Credential issued with ID: ${credentialId}`);
  
  // 4. Verify the credential
  console.log("\nVerifying credential...");
  
  const tx7 = await credentialVerificationModule.connect(issuer).verifyCredential(
    credentialId,
    1, // VERIFIED status
    "All requirements met"
  );
  await tx7.wait();
  console.log("Credential verified");
  
  // 5. Check credential validity
  console.log("\nChecking credential validity...");
  
  const isValid = await credentialNFT.isCredentialValid(credentialId);
  console.log(`Credential valid: ${isValid}`);
  
  // 6. Fetch credential metadata
  console.log("\nFetching credential metadata...");
  
  const metadata = await credentialNFT.getCredentialMetadata(credentialId);
  console.log(`Issuer: ${metadata.issuer}`);
  console.log(`Type: ${metadata.credentialType}`);
  console.log(`Status: ${metadata.verificationStatus}`);
  console.log(`Issued at: ${new Date(Number(metadata.issuedAt) * 1000).toISOString()}`);
  
  // 7. Fetch verification history
  console.log("\nFetching verification history...");
  
  const history = await credentialVerificationModule.getVerificationHistory(credentialId);
  console.log(`Verification history entries: ${history.length}`);
  for (let i = 0; i < history.length; i++) {
    console.log(`- Entry ${i}:`);
    console.log(`  Status: ${history[i].status}`);
    console.log(`  Timestamp: ${new Date(Number(history[i].timestamp) * 1000).toISOString()}`);
    console.log(`  Verifier: ${history[i].verifier}`);
    console.log(`  Notes: ${history[i].notes}`);
  }
  
  // 8. Test edge cases (optional)
  console.log("\nTesting edge cases...");
  
  // Duplicate submission - same person, same credential type
  try {
    console.log("Attempting duplicate credential submission...");
    await credentialVerificationModule.connect(issuer).issueCredential(
      talent.address,
      "Advanced Software Engineering Certificate",
      "Duplicate certificate",
      metadataURI,
      1, // CERTIFICATION type
      0,
      evidenceHash
    );
    console.log("Duplicate submission allowed - note: this is expected behavior");
  } catch (error) {
    console.log(`Duplicate submission error: ${error.message}`);
  }
  
  console.log("\nSimulation completed successfully!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });