const hh = require("hardhat")

async function main() {
  const ShyftBALV2LPStaking = await hh.ethers.getContractFactory("ShyftBALV2LPStaking")
  const BALV2Staking = await ShyftBALV2LPStaking.deploy("0xcba3eae7f55d0f423af43cc85e67ab0fbf87b61c")

  console.log("ShyftBALV2LPStaking was deployed to :: ", BALV2Staking.address, " successfully.");
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });