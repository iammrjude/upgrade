const { ethers, upgrades } = require('hardhat')

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  // type proxy address for upgrade contract
  // deployer must have upgrade access
  // const upgradeProxy = null
  // mumbai: '0xd95bF25D8E63975523bd5ba7d340A05794B6e4c0'
  // mainnet: '0xB1c5f44b6473EE2fdd22e5B65B971A8455442112'
  const upgradeProxy = '0xB1c5f44b6473EE2fdd22e5B65B971A8455442112'

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
      '0xeF6c0f160E18dE53f347498A75265C942ce3b035',
      '0x7dE86E55b84ec14bE4E319D54c8596975669DC10',
    ]
    const extraArgs = [
      '0x36E43065e977bC72CB86Dbd8405fae7057CDC7fD',
      1697860800,
      864000,
      7776000,
      '250000000000000000000000',
    ]
    const NORT = 6
    const rewardTokens = [
      '0x36E43065e977bC72CB86Dbd8405fae7057CDC7fD',
      '0x16C525C7cD751C19aDF26F39118154d7C4BD0088',
      '0xb0D8E79F484EC6DF92bfc032735D7F9B19e361eF',
      '0x92CC4e55DA0FC0AAC4dC780866e1514209c41f8d',
      '0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE',
      '0xc5fB36dd2fb59d3B98dEfF88425a3F425Ee469eD',
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
