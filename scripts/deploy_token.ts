import { ethers, upgrades } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);
  const Contract = await ethers.getContractFactory('PoodleHaney', deployer);
  const contract = await upgrades.deployProxy(
    Contract,
    [
      deployer.address,
      '0x10ED43C718714eb63d5aA57B78B54704E256024E',
      '0xDd62357E303bCb4BB1313c4DCc7BE3fE1D1126b5',
      '0xe3a78A0a573e01D2Fe0fF2787eCFE9b10FD0b962',
    ],
    {
      initializer: 'initialize',
      kind: 'uups',
    }
  );

  await contract.waitForDeployment();
  console.log('PoodleHaney deployed to:', contract.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
