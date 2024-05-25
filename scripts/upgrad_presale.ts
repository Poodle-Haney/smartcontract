const { ethers, upgrades } = require('hardhat');

// ** ETH
const UPGRADEABLE_PROXY = '0xD164AAC513782C9d78324eb2CA5Cf4c2fC3fd4A8';

// ** BSC
// const UPGRADEABLE_PROXY = '0xAe8CfDeE5a5B9CdbD30332bAD97E1AC0d70a18b4';

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
