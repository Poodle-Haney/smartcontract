const { ethers, upgrades } = require('hardhat');

// ** ETH
// const UPGRADEABLE_PROXY = '0xEEe070f52279843B1C31F2C32B952C481ad84272';

// ** BSC
const UPGRADEABLE_PROXY = '0x2Cc5C7B030Cc7AC89510aDa7795EC18AB65dC8eD';

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
