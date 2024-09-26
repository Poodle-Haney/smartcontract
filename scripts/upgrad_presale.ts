const { ethers, upgrades } = require('hardhat');

// ** ETH
// const UPGRADEABLE_PROXY = '0x9E32499b27fFD3b39fD062Bf4Ea559d8D29487A6';

// ** BSC
const UPGRADEABLE_PROXY = '0x224c9B07A4A515fAd9dc3527617e39b828C478e3';

async function main() {
  //   const gas = await ethers.provider.getGasPrice();
  const V2Contract = await ethers.getContractFactory('Presale');
  console.log('Upgrading V1Contract...');
  let upgrade = await upgrades.upgradeProxy(UPGRADEABLE_PROXY, V2Contract);
  console.log('V1 Upgraded to V2');
  console.log('V2 Contract Deployed To:', upgrade.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
