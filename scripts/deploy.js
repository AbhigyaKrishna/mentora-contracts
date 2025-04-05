const hre = require("hardhat");

async function main() {
  console.log("Deploying EduChain contract...");

  // Get the contract factory
  const CourseMarketplace = await hre.ethers.getContractFactory("CourseMarketplace");
  
  // Deploy the contract with initial platform fee of 5%
  const platformFeePercent = 5;
  const courseMarketplace = await CourseMarketplace.deploy(platformFeePercent);

  // Wait for deployment to finish
  await courseMarketplace.waitForDeployment();

  const address = await courseMarketplace.getAddress();
  console.log("EduChain deployed to:", address);
  console.log("Platform fee set to:", platformFeePercent, "%");
}

// Handle errors
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 