const hre = require("hardhat");
const path = require("path");
const fs = require("fs");
require("dotenv").config();

async function deployContract(contractName) {
  console.log(`\nDeploying ${contractName}...`);

  try {
    // Get the contract factory
    const Contract = await hre.ethers.getContractFactory(contractName);
    
    // Deploy the contract with appropriate constructor arguments
    let contract;
    if (contractName === "MentoraToken") {
      // MentoraToken constructor parameters from environment variables
      const initialSupply = hre.ethers.parseEther(process.env.INITIAL_SUPPLY || "100000000"); // Default: 100 million tokens
      const coursePurchaseReward = hre.ethers.parseEther(process.env.COURSE_PURCHASE_REWARD || "5"); // Default: 5 tokens
      const courseCompletionReward = hre.ethers.parseEther(process.env.COURSE_COMPLETION_REWARD || "10"); // Default: 10 tokens
      const contentCreationReward = hre.ethers.parseEther(process.env.CONTENT_CREATION_REWARD || "20"); // Default: 20 tokens
      const assignmentCompletionReward = hre.ethers.parseEther(process.env.ASSIGNMENT_COMPLETION_REWARD || "7"); // Default: 7 tokens
      
      console.log("Deploying MentoraToken with parameters:");
      console.log(`Initial Supply: ${initialSupply} (${process.env.INITIAL_SUPPLY || "100000000"} tokens)`);
      console.log(`Course Purchase Reward: ${coursePurchaseReward} (${process.env.COURSE_PURCHASE_REWARD || "5"} tokens)`);
      console.log(`Course Completion Reward: ${courseCompletionReward} (${process.env.COURSE_COMPLETION_REWARD || "10"} tokens)`);
      console.log(`Content Creation Reward: ${contentCreationReward} (${process.env.CONTENT_CREATION_REWARD || "20"} tokens)`);
      console.log(`Assignment Completion Reward: ${assignmentCompletionReward} (${process.env.ASSIGNMENT_COMPLETION_REWARD || "7"} tokens)`);
      
      contract = await Contract.deploy(
        initialSupply,
        coursePurchaseReward,
        courseCompletionReward,
        contentCreationReward,
        assignmentCompletionReward
      );
    } else if (contractName === "CourseManager") {
      const platformFeePercent = parseInt(process.env.PLATFORM_FEE_PERCENT || "5"); // Default: 5% platform fee
      console.log(`Platform Fee: ${platformFeePercent}%`);
      
      // Get MentoraToken address from environment or deployment
      let mentoraTokenAddress = process.env.MENTORA_TOKEN_ADDRESS;
      
      if (!mentoraTokenAddress) {
        // Get MentoraToken address from deployments if not provided in env
        const mentoraTokenDeploymentPath = path.join(__dirname, "..", "deployments", `MentoraToken-${hre.network.name}.json`);
        if (!fs.existsSync(mentoraTokenDeploymentPath)) {
          throw new Error("MentoraToken must be deployed first or MENTORA_TOKEN_ADDRESS must be set");
        }
        
        const mentoraTokenDeployment = JSON.parse(fs.readFileSync(mentoraTokenDeploymentPath, 'utf8'));
        mentoraTokenAddress = mentoraTokenDeployment.address;
      }
      
      console.log(`Using MentoraToken at: ${mentoraTokenAddress}`);
      contract = await Contract.deploy(platformFeePercent, mentoraTokenAddress);
    } else if (contractName === "AssignmentManager") {
      // Get MentoraToken address from environment or deployment
      let mentoraTokenAddress = process.env.MENTORA_TOKEN_ADDRESS;
      
      if (!mentoraTokenAddress) {
        // Get MentoraToken address from deployments if not provided in env
        const mentoraTokenDeploymentPath = path.join(__dirname, "..", "deployments", `MentoraToken-${hre.network.name}.json`);
        if (!fs.existsSync(mentoraTokenDeploymentPath)) {
          throw new Error("MentoraToken must be deployed first or MENTORA_TOKEN_ADDRESS must be set");
        }
        
        const mentoraTokenDeployment = JSON.parse(fs.readFileSync(mentoraTokenDeploymentPath, 'utf8'));
        mentoraTokenAddress = mentoraTokenDeployment.address;
      }
      
      console.log(`Using MentoraToken at: ${mentoraTokenAddress}`);
      contract = await Contract.deploy(mentoraTokenAddress);
    } else {
      // Other contracts don't need constructor arguments
      contract = await Contract.deploy();
    }

    // Wait for deployment to be mined
    await contract.waitForDeployment();
    const address = await contract.getAddress();

    console.log(`${contractName} deployed to:`, address);

    // Wait for confirmations
    const confirmations = parseInt(process.env.DEPLOYMENT_CONFIRMATIONS || "5");
    console.log(`Waiting for ${confirmations} confirmations...`);
    const deploymentTx = contract.deploymentTransaction();
    await deploymentTx.wait(confirmations);

    // Save deployment info
    const deploymentsDir = path.join(__dirname, "..", "deployments");
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir);
    }

    const deploymentInfo = {
      contractName: contractName,
      address: address,
      network: hre.network.name,
      deployer: deploymentTx.from,
      blockNumber: deploymentTx.blockNumber,
      timestamp: new Date().toISOString()
    };

    const deploymentPath = path.join(deploymentsDir, `${contractName}-${hre.network.name}.json`);
    fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
    console.log(`Deployment info saved to: ${deploymentPath}`);

    return address;
  } catch (error) {
    console.error(`Error deploying ${contractName}:`, error);
    throw error;
  }
}

async function main() {
  try {
    console.log("Starting deployment process...");

    // Get the contract name from environment variable or deploy all
    const contractName = process.env.CONTRACT_NAME;

    if (contractName) {
      // Deploy specific contract
      await deployContract(contractName);
    } else {
      // Define the deployment order for dependencies
      const deploymentOrder = (process.env.DEPLOYMENT_ORDER || "MentoraToken,CourseManager,AssignmentManager").split(",");
      
      for (const contractName of deploymentOrder) {
        try {
          await deployContract(contractName);
        } catch (error) {
          console.error(`Failed to deploy ${contractName}, continuing with next contract...`);
          continue;
        }
      }
    }

    console.log("\nDeployment process completed!");
  } catch (error) {
    console.error("Error in deployment process:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 