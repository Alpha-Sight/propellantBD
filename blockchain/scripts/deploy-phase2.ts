import { ethers } from "hardhat";
import { verify } from "./verify";

async function main() {
  console.log("Starting Phase 2 (Account Abstraction) deployment...");
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  // First, get the addresses of previously deployed modules
  // These should match the addresses from your deploy-phase1.ts output
  const roleModuleAddress = "0x597c42D3E14E04e1FE39ECd0c4f7Ba56060a0B51";
  const userProfileModuleAddress = "0x05fAE0FAA9bDece71ccDf4Ce351A85f86c5967aA";
  
  // Deploy EntryPoint (ERC-4337 standard)
  console.log("Deploying PropellantBDEntryPoint...");
  const EntryPoint = await ethers.getContractFactory("PropellantBDEntryPoint");
  const entryPoint = await EntryPoint.deploy();
  await entryPoint.waitForDeployment();
  const entryPointAddress = await entryPoint.getAddress();
  console.log(`EntryPoint deployed to: ${entryPointAddress}`);
  
  // Deploy AccountFactory
  console.log("Deploying PropellantBDAccountFactory...");
  const AccountFactory = await ethers.getContractFactory("PropellantBDAccountFactory");
  const accountFactory = await AccountFactory.deploy(
    entryPointAddress as unknown as string,
    userProfileModuleAddress as unknown as string
  );
  await accountFactory.waitForDeployment();
  const accountFactoryAddress = await accountFactory.getAddress();
  console.log(`AccountFactory deployed to: ${accountFactoryAddress}`);
  
  // Deploy Paymaster (with native token payments)
  console.log("Deploying PropellantBDPaymaster...");
  const Paymaster = await ethers.getContractFactory("PropellantBDPaymaster");
  const paymaster = await Paymaster.deploy(
    entryPointAddress as unknown as string,
    userProfileModuleAddress as unknown as string,
    roleModuleAddress as unknown as string,
    ethers.ZeroAddress // Use native token (no ERC20)
  );
  await paymaster.waitForDeployment();
  const paymasterAddress = await paymaster.getAddress();
  console.log(`Paymaster deployed to: ${paymasterAddress}`);
  
  // Deposit funds into the EntryPoint via the Paymaster to sponsor transactions.
  console.log("Depositing funds into EntryPoint for Paymaster...");
  await paymaster.deposit({ value: ethers.parseEther("0.01") });
  console.log("Funds deposited to EntryPoint successfully.");
  
  // Log all deployment addresses for reference
  console.log("\nDeployment Summary:");
  console.log("-------------------");
  console.log(`EntryPoint: ${entryPointAddress}`);
  console.log(`AccountFactory: ${accountFactoryAddress}`);
  console.log(`Paymaster: ${paymasterAddress}`);
  
  // Optional: Verify contracts on Etherscan/block explorer
  if (process.env.VERIFY_CONTRACTS === 'true') {
    console.log("\nVerifying contracts...");
    // Add delay to allow blockchain to index the contracts
    await new Promise(resolve => setTimeout(resolve, 60000));
    
    // Verify EntryPoint
    await verify(entryPointAddress, []);
    
    // Verify AccountFactory
    await verify(accountFactoryAddress, [entryPointAddress, userProfileModuleAddress]);
    
    // Verify Paymaster
    await verify(paymasterAddress, [
      entryPointAddress, 
      userProfileModuleAddress,
      roleModuleAddress,
      ethers.ZeroAddress
    ]);
    
    console.log("Contract verification completed!");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });