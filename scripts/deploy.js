const hre = require("hardhat");

async function main() {
  console.log("Deploying Mentora contract...");

  // Get the contract factory
  const CourseMarketplace = await hre.ethers.getContractFactory("Mentora");
  
  // Deploy the contract with initial platform fee of 5%
  const platformFeePercent = 5;
  const courseMarketplace = await CourseMarketplace.deploy(platformFeePercent);

  // Wait for deployment to finish
  await courseMarketplace.waitForDeployment();

  const address = await courseMarketplace.getAddress();
  console.log("Mentora deployed to:", address);
  console.log("Platform fee set to:", platformFeePercent, "%");
}

// Handle errors
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 