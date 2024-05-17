import { ethers, upgrades } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  const Contract = await ethers.getContractFactory('Presale', deployer);
  const contract = await upgrades.deployProxy(
    Contract,
    // ** Ether
    // [
    //   '0x4D084c9C2faA4aB089628d45D2c86F0C205d6Eb7',
    //   '0x935366A68942D577842acFFED610Cc26CD90ACA0',
    //   '0x55Ae632689Be114f1888a7f97DFc8a240a393AAE',
    //   '0x694AA1769357215DE4FAC081bf1f309aDC325306',
    // ],
    // ** BSC
    [
      '0x4D084c9C2faA4aB089628d45D2c86F0C205d6Eb7',
      '0x38daAcdcc9C328615aAc177957289B47de36f2d6',
      '0x987cA07Bc836f5b952cdCcE05A5084e55206637C',
      '0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526',
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
