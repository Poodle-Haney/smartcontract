import { ethers, upgrades } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  const Contract = await ethers.getContractFactory('Oracle', deployer);
  const contract = await upgrades.deployProxy(
    Contract,
    ['0x4D084c9C2faA4aB089628d45D2c86F0C205d6Eb7'],
    { initializer: 'initialize', kind: 'uups' },
  );

  await contract.waitForDeployment();
  console.log('Oracle deployed to:', contract.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
