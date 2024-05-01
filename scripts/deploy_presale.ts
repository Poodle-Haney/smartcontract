import { ethers, upgrades } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  const Contract = await ethers.getContractFactory('Presale', deployer);
  const contract = await upgrades.deployProxy(
    Contract,
    [
      '0x4D084c9C2faA4aB089628d45D2c86F0C205d6Eb7',
      '0x87Ce5D0B1Bc7D0d4ad73535CB703FD19f36b3162',
      '0x55Ae632689Be114f1888a7f97DFc8a240a393AAE',
      '0x694AA1769357215DE4FAC081bf1f309aDC325306',
    ],
    { initializer: 'initialize', kind: 'uups' },
  );

  await contract.waitForDeployment();
  console.log('Oracle deployed to:', contract.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
