import { ethers } from "hardhat";

async function main() {
  const txHash = "0x3ffddc9b940779ecb690bcd549445685b7559a8a2fd6040ea901138722468182";
  
  console.log(`Looking up credential ID from transaction: ${txHash}`);
  
  // Connect to the network
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  
  // Get transaction receipt
  const receipt = await provider.getTransactionReceipt(txHash);
  if (!receipt) {
    console.log("Transaction not found");
    return;
  }
  
  // Connect to credential module contract
  const credentialModuleAddress = "0x97EFAC0f624dD45ffBCF80e1779618d89104eF6C";
  const credentialABI = [
    "event CredentialSubmitted(uint256 indexed credentialId, address indexed issuer, address indexed subject)"
  ];
  const credentialInterface = new ethers.Interface(credentialABI);
  
  // Parse logs looking for CredentialSubmitted event
  for (const log of receipt.logs) {
    try {
      if (log.address.toLowerCase() === credentialModuleAddress.toLowerCase()) {
        const parsedLog = credentialInterface.parseLog({
          topics: log.topics,
          data: log.data
        });
        
        if (parsedLog && parsedLog.name === "CredentialSubmitted") {
          console.log(`✅ Found credential ID: ${parsedLog.args[0]}`);
          return;
        }
      }
    } catch (e) {
      // Not the event we're looking for
    }
  }
  
  console.log("No credential events found in this transaction");
}

main().catch(console.error);