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
    //   '0xe1ec81Ae89D771d524eD1F2d0D757284A4387e1d',
    //   '0xd3715D6D6AD4De5Fcc7cb2B2F743833Ac76029c8',
    //   '0x9E57E1B5746dd68697953B93A5F318A7643107d6',
    //   '0x694AA1769357215DE4FAC081bf1f309aDC325306',
    // ],
    // ** BSC
    [
      deployer.address,
      '0x37dF6ffA4A3D776Ff7C67a4c89F0336abE081D90',
      '0xaABA81872131797BD2b7743A56Dc926C4d79B245',
      '0x3ac049c6E91a2c1b3A94431135F48e28F712F146',
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
