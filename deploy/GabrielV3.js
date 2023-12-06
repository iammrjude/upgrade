const { ethers, upgrades } = require('hardhat')

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  // type proxy address for upgrade contract
  // deployer must have upgrade access
  // const upgradeProxy = null // mumbai: '0x4355f8f76674d27c4D6fE476Dfbb9dcbb858b098'
  const upgradeProxy = '0x4355f8f76674d27c4D6fE476Dfbb9dcbb858b098'

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

    if (hre.network.name == 'polygon') {}

    const constructorArgs = [50,50, "0xF6f2D0A9F55C61240427A6AA9dE62419EC8539f8", "0x7F6cf0C863df72248606aB399D70C02A50AFd151"]
    const extraArgs = ["0xbFb7af1d2450711A3187018973B395c6b14E0E3B", 1700757301, 1080, 420, 250000000000000000000000n]
    const NORT = 4
    const rewardTokens = ["0xbFb7af1d2450711A3187018973B395c6b14E0E3B", "0x972Ac85E66d3daEa10C29E223B85e76954D36F81", "0xE857F4Ca293fb73547a06De6282ea78EfE5829fE", "0x16CE02bdeA3bdBbbe644b399A2834488D4B22684"]
    const staticRewardsInPool = ["100000000000000000000000","650000000000000000000000000000","300000000000000000000000","500000000000000000000000"]

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
  }
}

module.exports.tags = ['GabrielV3']
module.exports.dependencies = ['ProfitToken', 'DividendToken']
