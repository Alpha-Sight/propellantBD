import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

// This ensures we don't get undefined errors when running tests locally
const WALLET_KEY = process.env.WALLET_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    // Local development network
    hardhat: {
      // No special configuration needed for tests
    },
    // Lisk Sepolia testnet (for deployments)
    'lisk-sepolia': {
      url: 'https://rpc.sepolia-api.lisk.com',
      accounts: [WALLET_KEY],
      gasPrice: 1000000000,
    },
  },
  // Custom verification configuration
  etherscan: {
    apiKey: {
      // Use default API key for Lisk
      "lisk-sepolia": ETHERSCAN_API_KEY
    },
    customChains: [
      {
        network: "lisk-sepolia",
        chainId: 4202,
        urls: {
          // Updated URLs with correct Blockscout explorer
          apiURL: "https://sepolia-blockscout.lisk.com/api",
          browserURL: "https://sepolia-blockscout.lisk.com"
        }
      }
    ]
  }
};

export default config;