const { ethers, upgrades } = require('hardhat')

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  // type proxy address for upgrade contract
  // deployer must have upgrade access
  // const upgradeProxy = null
  // mumbai: '0xd95bF25D8E63975523bd5ba7d340A05794B6e4c0'
  // mainnet: '0xB1c5f44b6473EE2fdd22e5B65B971A8455442112'
  const upgradeProxy = '0xd95bF25D8E63975523bd5ba7d340A05794B6e4c0'

  const { save, get } = deployments
  const { deployer } = await getNamedAccounts()
  const chainId = await getChainId()

  console.log('')

  // noinspection PointlessBooleanExpressionJS
  if (!upgradeProxy) {
    console.log(`== GabrielV3 deployment to ${hre.network.name} ==`)
    try {
      const deplpoyment = await get('GabrielV3')
      console.log(
        `GabrielV3 already deployed to ${hre.network.name} at ${deplpoyment.address}`
      )
      return
    } catch (e) {
      // not deployed yet
    }

    const constructorArgs = [
      50,
      50,
      '0xF6f2D0A9F55C61240427A6AA9dE62419EC8539f8',
      '0x7F6cf0C863df72248606aB399D70C02A50AFd151',
    ]
    const extraArgs = [
      '0xbFb7af1d2450711A3187018973B395c6b14E0E3B',
      1701943605,
      1080,
      420,
      250000000000000000000000n,
    ]
    const NORT = 6
    const rewardTokens = [
      '0xbFb7af1d2450711A3187018973B395c6b14E0E3B',
      '0x972Ac85E66d3daEa10C29E223B85e76954D36F81',
      '0x16CE02bdeA3bdBbbe644b399A2834488D4B22684',
      '0xE857F4Ca293fb73547a06De6282ea78EfE5829fE',
      '0x2cEb626882154DD9E057da57DD8A58a1EF6459D2',
      '0xC0b1E6a66FF66E1EaD2BE54CdaDfF1D9eb8d751D',
    ]
    const staticRewardsInPool = [
      '100000000000000000000000',
      '125000000000000000000000000000',
      '300000000000000000000000',
      '450000000000000000000000',
      '100000000000000000000000000',
      '24000000000000',
    ]

    console.log('ChainId:', chainId)
    console.log('Deployer address:', deployer)

    const GabrielV3 = await ethers.getContractFactory('GabrielV3')
    const gabrielV3 = await upgrades.deployProxy(
      GabrielV3,
      [constructorArgs, extraArgs, NORT, rewardTokens, staticRewardsInPool],
      {
        kind: 'uups',
      }
    )

    await gabrielV3.deployed()

    const artifact = await hre.artifacts.readArtifact('GabrielV3')

    await save('GabrielV3', {
      address: gabrielV3.address,
      abi: artifact.abi,
    })

    let receipt = await gabrielV3.deployTransaction.wait()
    console.log(
      `GabrielV3 proxy deployed at: ${gabrielV3.address} (block: ${
        receipt.blockNumber
      }) with ${receipt.gasUsed.toNumber()} gas`
    )
  } else {
    console.log(`==== GabrielV3 upgrade at ${hre.network.name} ====`)
    console.log(`Proxy address: ${upgradeProxy}`)

    // try to upgrade
    const GabrielV3 = await ethers.getContractFactory('GabrielV3')
    const gabrielV3 = await upgrades.upgradeProxy(upgradeProxy, GabrielV3)

    const artifact = await hre.artifacts.readArtifact('GabrielV3')

    await save('GabrielV3', {
      address: gabrielV3.address,
      abi: artifact.abi,
    })

    let receipt = await gabrielV3.deployTransaction.wait()
    console.log(
      `GabrielV3 upgraded through proxy: ${gabrielV3.address} (block: ${
        receipt.blockNumber
      }) with ${receipt.gasUsed.toNumber()} gas`
    )

    // hardhat verify --network r.. 0x
    // npx hardhat verify --network <network> <address>
    // npx hardhat verify --network mumbai 0xC745f8731858b4D9dA26B2dFF5d1A307A6B32255
  }
}

module.exports.tags = ['GabrielV3']
