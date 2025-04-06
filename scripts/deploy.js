const hre = require("hardhat");

async function main() {
  console.log("Deploying Mentora contract...");

  // Get the contract factory
  const Mentora = await hre.ethers.getContractFactory("Mentora");
  
  // Deploy the contract with initial platform fee of 5%
  const platformFeePercent = process.env.PLATFORM_FEE_PERCENT || 5;
  const mentora = await Mentora.deploy(platformFeePercent);

  // Wait for deployment to finish
  await mentora.waitForDeployment();

  const mentoraAddress = await mentora.getAddress();
  console.log("Mentora deployed to:", mentoraAddress);
  console.log("Platform fee set to:", platformFeePercent, "%");

  console.log("Deploying AssignmentManager contract...");
  
  // Get the AssignmentManager contract factory
  const AssignmentManager = await hre.ethers.getContractFactory("AssignmentManager");
  
  // Deploy the AssignmentManager contract
  const assignmentManager = await AssignmentManager.deploy();
  
  // Wait for deployment to finish
  await assignmentManager.waitForDeployment();
  
  const assignmentManagerAddress = await assignmentManager.getAddress();
  console.log("AssignmentManager deployed to:", assignmentManagerAddress);
}

// Handle errors
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 