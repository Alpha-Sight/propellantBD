import { ethers } from "hardhat";

async function main() {
  const OLD_ACCOUNT_FACTORY_ADDRESS = "0x2c8F8457ec7f54Aeac5E6FEF04f835380EF32dCE"; // Replace with the old AccountFactory address
  const NEW_ACCOUNT_FACTORY_ADDRESS = "0x33A886313Afaa42B4d74FADbA8b4e5bBC838F681"; // Replace with the new AccountFactory address

  const oldAccountFactoryABI = [
    "function getAccount(address owner) public view returns (address)"
  ];
  const newAccountFactoryABI = [
    "function createAccount(address owner, uint256 salt) public returns (address)"
  ];

  const [deployer] = await ethers.getSigners();

  // Connect to the old and new AccountFactory contracts
  const oldAccountFactory = new ethers.Contract(
    OLD_ACCOUNT_FACTORY_ADDRESS,
    oldAccountFactoryABI,
    deployer
  );
  const newAccountFactory = new ethers.Contract(
    NEW_ACCOUNT_FACTORY_ADDRESS,
    newAccountFactoryABI,
    deployer
  );

  // List of user addresses to migrate
  const userAddresses = [
    "0xUserAddress1",
    "0xUserAddress2",
    "0xUserAddress3"
    // Add all user addresses here
  ];

  for (const userAddress of userAddresses) {
    // Query the old AccountFactory for the user's account
    const oldAccount = await oldAccountFactory.getAccount(userAddress);

    if (oldAccount === ethers.ZeroAddress) {
      console.log(`No account found for user: ${userAddress}`);
      continue;
    }

    console.log(`Migrating account for user: ${userAddress}, old account: ${oldAccount}`);

    // Recreate the account in the new AccountFactory
    const salt = 0; // Use the same salt as before
    const tx = await newAccountFactory.createAccount(userAddress, salt);
    await tx.wait();

    console.log(`Account migrated for user: ${userAddress}`);
  }

  console.log("Migration completed!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});