import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-ethers';
import '@openzeppelin/hardhat-upgrades';
import dotenv from 'dotenv';
dotenv.config();

const MAIN_RPC_URL = `https://mainnet.infura.io/v3/${process.env.INFURA_KEY}`;
const SEPOLIA_RPC_URL = `https://sepolia.infura.io/v3/${process.env.INFURA_KEY}`;
const BSC_RPC_URL = `https://bsc-dataseed.binance.org/`;
const BSC_TEST_RPC_URL = `https://bsc-testnet.core.chainstack.com/6f56a5ff9769149a832eed5cc4fc1135`;
const PRIVATE_KEY = process.env.PRIVATE_KEY ?? '';
const POODLE_PRIVATE_KEY = process.env.POODLE_PRIVATE_KEY ?? '';

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.24',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: 'istanbul',
          viaIR: true,
        },
      },
    ],
  },
  networks: {
    main: {
      url: MAIN_RPC_URL,
      accounts: [POODLE_PRIVATE_KEY],
    },
    sepolia: {
      url: SEPOLIA_RPC_URL,
      accounts: [PRIVATE_KEY],
    },
    bsc: {
      url: BSC_RPC_URL,
      accounts: [POODLE_PRIVATE_KEY],
    },
    bscTest: {
      url: BSC_TEST_RPC_URL,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      mainnet: '3JNWMNHJ8KKWBEJ3NXANMPCQTS7FIY8CX9',
      sepolia: '3JNWMNHJ8KKWBEJ3NXANMPCQTS7FIY8CX9',
      bsc: 'DI1QQQ1Z469QBD2MA2TBKM1AJX9RMHM28C',
      bscTestnet: 'DI1QQQ1Z469QBD2MA2TBKM1AJX9RMHM28C',
    },
  },
  sourcify: {
    enabled: true,
  },
};

export default config;
