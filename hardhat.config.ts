import 'hardhat-deploy'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-etherscan'
import 'solidity-coverage'
import 'hardhat-gas-reporter'
import '@openzeppelin/hardhat-upgrades'
import '@typechain/hardhat'
import '@nomiclabs/hardhat-web3'
require('dotenv').config()

const accounts = {
  mnemonic:
    process.env.MNEMONIC ||
    'syrup test test test test test test test test test test test',
}

module.exports = {
  solidity: {
    version: '0.8.22',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  gasReporter: {
    currency: 'USD',
    enabled: process.env.REPORT_GAS === 'true',
    gasPrice: 120,
    gasMultiplier: 2,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    tester: {
      default: 2,
    },
  },
  networks: {
    mainnet: {
      url: `${process.env.URL_MAINNET}`,
      saveDeployments: true,
      accounts,
      gasPrice: 113000000000,
    },
    polygon: {
      chainId: 137,
      url: `${process.env.URL_POLYGON}`,
      saveDeployments: true,
      accounts,
      gasPrice: 100000000000, // 100 gwei
    },
    goerli: {
      url: `${process.env.URL_GOERLI}`,
      saveDeployments: true,
      accounts,
    },
    mumbai: {
      chainId: 80001,
      url: `${process.env.URL_MUMBAI}`,
      saveDeployments: true,
      accounts,
      // gasPrice: 110000000000,
    },
    hardhat: {
      chainId: 1337, // https://hardhat.org/metamask-issue.html
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
}
