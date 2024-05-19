import { ethers, upgrades } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  const Contract = await ethers.getContractFactory('Oracle', deployer);
  const contract = await upgrades.deployProxy(Contract, [deployer.address], {
    initializer: 'initialize',
    kind: 'uups',
  });

  await contract.waitForDeployment();
  console.log('Oracle deployed to:', contract.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
