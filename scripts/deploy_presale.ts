import { ethers, upgrades } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  const chainId = (await deployer.provider.getNetwork()).chainId;
  console.log((await deployer.provider.getNetwork()).chainId);
  const Contract = await ethers.getContractFactory('Presale', deployer);
  const contract = await upgrades.deployProxy(
    Contract,
    // ** Ether
    // [
    //   deployer.address,
    //   '0x19d121268c5B3d5547aA3Ff33bC8372A1DAb5748',
    //   '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    //   '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    //   '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
    // ],
    // ** BSC
    [
      deployer.address,
      '0xe8Da9c271Ef73aD0D04EbAfBE7EfA8D90b25c1B1',
      '0x55d398326f99059fF775485246999027B3197955',
      '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
      '0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE',
    ],
    { initializer: 'initialize', kind: 'uups' }
  );

  await contract.waitForDeployment();

  console.log('Oracle deployed to:', contract.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
