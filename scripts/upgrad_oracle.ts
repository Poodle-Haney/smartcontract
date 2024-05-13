const { ethers, upgrades } = require('hardhat');

// ETH
// const UPGRADEABLE_PROXY = '0x9fB08f612C69e359237a8Cc84AA5f56c821E01d8';

// ** BSC
const UPGRADEABLE_PROXY = '0x87Ce5D0B1Bc7D0d4ad73535CB703FD19f36b3162';

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
