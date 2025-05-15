import { run } from "hardhat";

export async function verify(contractAddress: string, args: any[]) {
  console.log(`Verifying contract at address: ${contractAddress}`);
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
    console.log(`Contract verification successful for ${contractAddress}`);
  } catch (error: any) {
    if (error.message.includes("already verified")) {
      console.log(`Contract ${contractAddress} is already verified`);
    } else {
      console.error(`Error verifying contract ${contractAddress}:`, error);
    }
  }
}