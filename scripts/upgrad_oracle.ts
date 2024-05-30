const { ethers, upgrades } = require('hardhat');

// ETH
const UPGRADEABLE_PROXY = '0xc806F89594Cd206e2a53f183718F1Ace0f8D5836';

// ** BSC
// const UPGRADEABLE_PROXY = '0x0Fe58F912b2445dbB1A2f1320dc7697c41f1F480';

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
