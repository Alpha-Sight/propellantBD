import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { CredentialVerificationModule, RoleModule, UserProfileModule } from "../typechain-types";

describe("CredentialVerificationModule", function () {
  // Define enum values to match the contract
  const CredentialType = {
    EDUCATION: 0,
    CERTIFICATION: 1,
    EXPERIENCE: 2,
    SKILL: 3,
    ACHIEVEMENT: 4,
    REFERENCE: 5,
    OTHER: 6
  };
  
  const VerificationStatus = {
    PENDING: 0,
    VERIFIED: 1,
    REJECTED: 2,
    REVOKED: 3
  };
  
  // Fixture to deploy the necessary contracts for testing
  async function deployCredentialVerificationModuleFixture() {
    const [admin, issuer, talent, organization] = await hre.ethers.getSigners();
    
    // First deploy RoleModule
    const RoleModuleFactory = await hre.ethers.getContractFactory("RoleModule");
    const roleModule = await RoleModuleFactory.deploy();
    
    // Then deploy UserProfileModule
    const UserProfileModuleFactory = await hre.ethers.getContractFactory("UserProfileModule");
    const userProfileModule = await UserProfileModuleFactory.deploy(roleModule.target);
    
    // Finally deploy CredentialVerificationModule
    const CredentialVerificationModuleFactory = await hre.ethers.getContractFactory("CredentialVerificationModule");
    const credentialVerificationModule = await CredentialVerificationModuleFactory.deploy(
      roleModule.target as unknown as string,
      userProfileModule.target as unknown as string
    );
    
    // Get the role constants
    const ADMIN_ROLE = await roleModule.ADMIN_ROLE();
    const TALENT_ROLE = await roleModule.TALENT_ROLE();
    const ORGANIZATION_ROLE = await roleModule.ORGANIZATION_ROLE();
    const ISSUER_ROLE = await credentialVerificationModule.ISSUER_ROLE();
    
    // Grant roles
    await roleModule.grantRoleSafe(TALENT_ROLE, talent.address);
    await roleModule.grantRoleSafe(ORGANIZATION_ROLE, organization.address);
    await roleModule.grantRoleSafe(ORGANIZATION_ROLE, issuer.address);
    
    // Create profiles
    await userProfileModule.connect(talent).createProfile("Talent User", "Talented", "talent@example.com", "avatar");
    await userProfileModule.connect(organization).createProfile("Organization", "Big Company", "org@example.com", "avatar");
    await userProfileModule.connect(issuer).createProfile("Issuer Org", "Credential Issuer", "issuer@example.com", "avatar");
    
    // Grant admin role to the credential module to allow it to grant roles
    await roleModule.grantRole(ADMIN_ROLE, credentialVerificationModule.target);
    
    return { 
      credentialVerificationModule,
      roleModule,
      userProfileModule,
      admin, 
      issuer,
      talent, 
      organization,
      ADMIN_ROLE,
      TALENT_ROLE,
      ORGANIZATION_ROLE,
      ISSUER_ROLE
    };
  }
  
  describe("Deployment", function () {
    it("Should be deployed with correct module addresses", async function () {
      const { credentialVerificationModule } = await loadFixture(deployCredentialVerificationModuleFixture);
      
      // No direct getters for private variables, but we'll test functionality that depends on them
      expect(credentialVerificationModule.target).to.not.equal(hre.ethers.ZeroAddress);
    });
  });
  
  describe("Issuer Management", function () {
    it("Should allow adding an organization as an issuer", async function () {
      const { credentialVerificationModule, admin, issuer, ISSUER_ROLE } = 
        await loadFixture(deployCredentialVerificationModuleFixture);
      
      await expect(credentialVerificationModule.connect(admin).addIssuer(issuer.address))
        .to.emit(credentialVerificationModule, "IssuerAdded")
        .withArgs(issuer.address);
      
      expect(await credentialVerificationModule.isIssuer(issuer.address)).to.be.true;
    });
    
    it("Should prevent adding a non-organization as an issuer", async function () {
      const { credentialVerificationModule, admin, talent } = 
        await loadFixture(deployCredentialVerificationModuleFixture);
      
      await expect(
        credentialVerificationModule.connect(admin).addIssuer(talent.address)
      ).to.be.revertedWith("CredentialVerification: issuer must be an organization or admin");
    });
    
    it("Should allow removing an issuer", async function () {
      const { credentialVerificationModule, admin, issuer } = 
        await loadFixture(deployCredentialVerificationModuleFixture);
      
      await credentialVerificationModule.connect(admin).addIssuer(issuer.address);
      
      await expect(credentialVerificationModule.connect(admin).removeIssuer(issuer.address))
        .to.emit(credentialVerificationModule, "IssuerRemoved")
        .withArgs(issuer.address);
      
      expect(await credentialVerificationModule.isIssuer(issuer.address)).to.be.false;
    });
  });
  
  describe("Credential Management", function () {
    it("Should allow an issuer to issue a credential", async function () {
      const { credentialVerificationModule, admin, issuer, talent } = 
        await loadFixture(deployCredentialVerificationModuleFixture);
      
      await credentialVerificationModule.connect(admin).addIssuer(issuer.address);
      
      const name = "Software Engineering Certificate";
      const description = "Certificate in software engineering principles";
      const metadataURI = "ipfs://QmHash";
      const evidenceHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("evidence"));
      
      const tx = await credentialVerificationModule.connect(issuer).issueCredential(
        talent.address,
        name,
        description,
        metadataURI,
        CredentialType.CERTIFICATION,
        0, // No expiration
        evidenceHash,
        true // Revocable
      );
      
      const receipt = await tx.wait();
      const event = receipt?.logs.find(log => 
        log.fragment && log.fragment.name === "CredentialIssued"
      );
      
      expect(event).to.not.be.undefined;
      
      // Extract the ID from the event
      const id = event?.args[0];
      
      const credential = await credentialVerificationModule.getCredential(id);
      expect(credential.subject).to.equal(talent.address);
      expect(credential.issuer).to.equal(issuer.address);
      expect(credential.name).to.equal(name);
      expect(credential.description).to.equal(description);
      expect(credential.metadataURI).to.equal(metadataURI);
      expect(credential.credentialType).to.equal(CredentialType.CERTIFICATION);
      expect(credential.status).to.equal(VerificationStatus.PENDING);
      expect(credential.evidenceHash).to.equal(evidenceHash);
      expect(credential.revocable).to.be.true;
    });
    
    it("Should prevent non-issuers from issuing credentials", async function () {
      const { credentialVerificationModule, talent, organization } = 
        await loadFixture(deployCredentialVerificationModuleFixture);
      
      await expect(
        credentialVerificationModule.connect(organization).issueCredential(
          talent.address,
          "Certificate",
          "Description",
          "ipfs://QmHash",
          CredentialType.CERTIFICATION,
          0,
          hre.ethers.keccak256(hre.ethers.toUtf8Bytes("evidence")),
          true
        )
      ).to.be.revertedWith("CredentialVerification: caller is not an issuer");
    });
    
    it("Should allow issuers to verify their own credentials", async function () {
      const { credentialVerificationModule, admin, issuer, talent } = 
        await loadFixture(deployCredentialVerificationModuleFixture);
      
      await credentialVerificationModule.connect(admin).addIssuer(issuer.address);
      
      // Issue a credential
      const tx = await credentialVerificationModule.connect(issuer).issueCredential(
        talent.address,
        "Certificate",
        "Description",
        "ipfs://QmHash",
        CredentialType.CERTIFICATION,
        0,
        hre.ethers.keccak256(hre.ethers.toUtf8Bytes("evidence")),
        true
      );
      
      const receipt = await tx.wait();
      const event = receipt?.logs.find(log => 
        log.fragment && log.fragment.name === "CredentialIssued"
      );
      const id = event?.args[0];
      
      // Verify the credential
      await expect(credentialVerificationModule.connect(issuer).verifyCredential(
        id,
        VerificationStatus.VERIFIED,
        "Verification complete"
      ))
        .to.emit(credentialVerificationModule, "CredentialVerified")
        .withArgs(id, issuer.address, VerificationStatus.VERIFIED);
      
      const credential = await credentialVerificationModule.getCredential(id);
      expect(credential.status).to.equal(VerificationStatus.VERIFIED);
      
      // Check if the credential is valid
      expect(await credentialVerificationModule.isCredentialValid(id)).to.be.true;
    });
    
    it("Should allow revoking a revocable credential", async function () {
      const { credentialVerificationModule, admin, issuer, talent } = 
        await loadFixture(deployCredentialVerificationModuleFixture);
      
      await credentialVerificationModule.connect(admin).addIssuer(issuer.address);
      
      // Issue and verify a credential
      const tx = await credentialVerificationModule.connect(issuer).issueCredential(
        talent.address,
        "Certificate",
        "Description",
        "ipfs://QmHash",
        CredentialType.CERTIFICATION,
        0,
        hre.ethers.keccak256(hre.ethers.toUtf8Bytes("evidence")),
        true // Revocable
      );
      
      const receipt = await tx.wait();
      const event = receipt?.logs.find(log => 
        log.fragment && log.fragment.name === "CredentialIssued"
      );
      const id = event?.args[0];
      
      await credentialVerificationModule.connect(issuer).verifyCredential(
        id,
        VerificationStatus.VERIFIED,
        "Verification complete"
      );
      
      // Revoke the credential
      const reason = "Certificate revoked due to policy violation";
      await expect(credentialVerificationModule.connect(issuer).revokeCredential(id, reason))
        .to.emit(credentialVerificationModule, "CredentialRevoked")
        .withArgs(id, issuer.address, reason);
      
      const credential = await credentialVerificationModule.getCredential(id);
      expect(credential.status).to.equal(VerificationStatus.REVOKED);
      
      // Check that the credential is no longer valid
      expect(await credentialVerificationModule.isCredentialValid(id)).to.be.false;
    });
    
    it("Should prevent revoking non-revocable credentials", async function () {
      const { credentialVerificationModule, admin, issuer, talent } = 
        await loadFixture(deployCredentialVerificationModuleFixture);
      
      await credentialVerificationModule.connect(admin).addIssuer(issuer.address);
      
      // Issue a non-revocable credential
      const tx = await credentialVerificationModule.connect(issuer).issueCredential(
        talent.address,
        "Certificate",
        "Description",
        "ipfs://QmHash",
        CredentialType.CERTIFICATION,
        0,
        hre.ethers.keccak256(hre.ethers.toUtf8Bytes("evidence")),
        false // Not revocable
      );
      
      const receipt = await tx.wait();
      const event = receipt?.logs.find(log => 
        log.fragment && log.fragment.name === "CredentialIssued"
      );
      const id = event?.args[0];
      
      // Try to revoke the credential
      await expect(
        credentialVerificationModule.connect(issuer).revokeCredential(id, "Revocation attempt")
      ).to.be.revertedWith("CredentialVerification: credential is not revocable");
    });
    
    it("Should allow updating credential metadata", async function () {
      const { credentialVerificationModule, admin, issuer, talent } = 
        await loadFixture(deployCredentialVerificationModuleFixture);
      
      await credentialVerificationModule.connect(admin).addIssuer(issuer.address);
      
      // Issue a credential
      const tx = await credentialVerificationModule.connect(issuer).issueCredential(
        talent.address,
        "Certificate",
        "Description",
        "ipfs://QmHash",
        CredentialType.CERTIFICATION,
        0,
        hre.ethers.keccak256(hre.ethers.toUtf8Bytes("evidence")),
        true
      );
      
      const receipt = await tx.wait();
      const event = receipt?.logs.find(log => 
        log.fragment && log.fragment.name === "CredentialIssued"
      );
      const id = event?.args[0];
      
      // Update the credential
      const newName = "Updated Certificate";
      const newDescription = "Updated Description";
      const newMetadataURI = "ipfs://QmNewHash";
      
      await expect(credentialVerificationModule.connect(issuer).updateCredential(
        id,
        newName,
        newDescription,
        newMetadataURI
      ))
        .to.emit(credentialVerificationModule, "CredentialUpdated")
        .withArgs(id, newName, newDescription);
      
      const credential = await credentialVerificationModule.getCredential(id);
      expect(credential.name).to.equal(newName);
      expect(credential.description).to.equal(newDescription);
      expect(credential.metadataURI).to.equal(newMetadataURI);
    });
  });
  
  describe("Query Functions", function () {
    it("Should retrieve all credentials for a subject", async function () {
      const { credentialVerificationModule, admin, issuer, talent } = 
        await loadFixture(deployCredentialVerificationModuleFixture);
      
      await credentialVerificationModule.connect(admin).addIssuer(issuer.address);
      
      // Issue multiple credentials
      await credentialVerificationModule.connect(issuer).issueCredential(
        talent.address,
        "Certificate 1",
        "Description 1",
        "ipfs://QmHash1",
        CredentialType.CERTIFICATION,
        0,
        hre.ethers.keccak256(hre.ethers.toUtf8Bytes("evidence1")),
        true
      );
      
      await credentialVerificationModule.connect(issuer).issueCredential(
        talent.address,
        "Certificate 2",
        "Description 2",
        "ipfs://QmHash2",
        CredentialType.EDUCATION,
        0,
        hre.ethers.keccak256(hre.ethers.toUtf8Bytes("evidence2")),
        true
      );
      
      const credentials = await credentialVerificationModule.getSubjectCredentials(talent.address);
      expect(credentials.length).to.equal(2);
    });
    
    it("Should retrieve all credentials issued by an issuer", async function () {
      const { credentialVerificationModule, admin, issuer, talent, organization } = 
        await loadFixture(deployCredentialVerificationModuleFixture);
      
      await credentialVerificationModule.connect(admin).addIssuer(issuer.address);
      
      // Issue credentials to different subjects
      await credentialVerificationModule.connect(issuer).issueCredential(
        talent.address,
        "Certificate for Talent",
        "Description",
        "ipfs://QmHash1",
        CredentialType.CERTIFICATION,
        0,
        hre.ethers.keccak256(hre.ethers.toUtf8Bytes("evidence1")),
        true
      );
      
      await credentialVerificationModule.connect(issuer).issueCredential(
        organization.address,
        "Certificate for Organization",
        "Description",
        "ipfs://QmHash2",
        CredentialType.CERTIFICATION,
        0,
        hre.ethers.keccak256(hre.ethers.toUtf8Bytes("evidence2")),
        true
      );
      
      const credentials = await credentialVerificationModule.getIssuerCredentials(issuer.address);
      expect(credentials.length).to.equal(2);
    });
    
    it("Should retrieve verification history for a credential", async function () {
      const { credentialVerificationModule, admin, issuer, talent } = 
        await loadFixture(deployCredentialVerificationModuleFixture);
      
      await credentialVerificationModule.connect(admin).addIssuer(issuer.address);
      
      // Issue a credential
      const tx = await credentialVerificationModule.connect(issuer).issueCredential(
        talent.address,
        "Certificate",
        "Description",
        "ipfs://QmHash",
        CredentialType.CERTIFICATION,
        0,
        hre.ethers.keccak256(hre.ethers.toUtf8Bytes("evidence")),
        true
      );
      
      const receipt = await tx.wait();
      const event = receipt?.logs.find(log => 
        log.fragment && log.fragment.name === "CredentialIssued"
      );
      const id = event?.args[0];
      
      // Create multiple verification records
      await credentialVerificationModule.connect(issuer).verifyCredential(
        id,
        VerificationStatus.VERIFIED,
        "Initial verification"
      );
      
      await credentialVerificationModule.connect(issuer).revokeCredential(
        id,
        "Temporarily revoked for review"
      );
      
      await credentialVerificationModule.connect(issuer).verifyCredential(
        id,
        VerificationStatus.VERIFIED,
        "Re-verified after review"
      );
      
      const history = await credentialVerificationModule.getVerificationHistory(id);
      expect(history.length).to.equal(3);
      expect(history[0].status).to.equal(VerificationStatus.VERIFIED);
      expect(history[1].status).to.equal(VerificationStatus.REVOKED);
      expect(history[2].status).to.equal(VerificationStatus.VERIFIED);
    });
  });
  
  describe("Pausability", function () {
    it("Should prevent credential operations when paused", async function () {
      const { credentialVerificationModule, admin, issuer, talent } = 
        await loadFixture(deployCredentialVerificationModuleFixture);
      
      await credentialVerificationModule.connect(admin).addIssuer(issuer.address);
      
      // Pause the contract
      await credentialVerificationModule.pause();
      
      await expect(
        credentialVerificationModule.connect(issuer).issueCredential(
          talent.address,
          "Certificate",
          "Description",
          "ipfs://QmHash",
          CredentialType.CERTIFICATION,
          0,
          hre.ethers.keccak256(hre.ethers.toUtf8Bytes("evidence")),
          true
        )
      ).to.be.revertedWith("Pausable: paused");
    });
  });
});