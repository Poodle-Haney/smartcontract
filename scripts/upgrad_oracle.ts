const { ethers, upgrades } = require('hardhat');

// ETH
// const UPGRADEABLE_PROXY = '0xe1ec81Ae89D771d524eD1F2d0D757284A4387e1d';

// ** BSC
const UPGRADEABLE_PROXY = '0x37dF6ffA4A3D776Ff7C67a4c89F0336abE081D90';

async function main() {
  //   const gas = await ethers.provider.getGasPrice();
  const V2Contract = await ethers.getContractFactory('Oracle');
  console.log('Upgrading V1Contract...');
  let upgrade = await upgrades.upgradeProxy(UPGRADEABLE_PROXY, V2Contract);
  console.log('V1 Upgraded to V2');
  console.log('V2 Contract Deployed To:', upgrade.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

export {};
