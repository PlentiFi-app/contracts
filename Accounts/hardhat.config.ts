import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import { HardhatUserConfig } from "hardhat/config";
import "hardhat-spdx-license-identifier";
import "hardhat-contract-sizer";
import 'hardhat-deploy';
import "dotenv/config";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.25",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.23",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
    overrides: {
      "src/plentifi/webAuthnValidator/*": {
        version: "0.8.23",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: true,
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
  networks: {
    local: {
      url: process.env.NETWORK_URL || "0x0000000000000000000000000000000000000000000000000000000000000000",
      accounts: [process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000"],
    },
    holesky: {
      url: process.env.HOLESKY_TESTNET_URL || "0x0000000000000000000000000000000000000000000000000000000000000000",
      accounts: [process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000"],
    },
    arbitrumSepolia: {
      url: process.env.ARBITRUM_SEPOLIA_URL || "0x0000000000000000000000000000000000000000000000000000000000000000",
      accounts: [process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000"],
    },
    scrollSepolia: {
      url: process.env.SCROLL_SEPOLIA_URL || "0x0000000000000000000000000000000000000000000000000000000000000000",
      accounts: [process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000"],
    }
  },
};

export default config;
