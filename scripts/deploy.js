const hre = require("hardhat");
const path = require("path");
const fs = require("fs");

async function deployContract(contractName) {
  console.log(`\nDeploying ${contractName}...`);

  try {
    // Get the contract factory
    const Contract = await hre.ethers.getContractFactory(contractName);
    
    // Deploy the contract with appropriate constructor arguments
    let contract;
    if (contractName === "CourseManager") {
      // Mentora requires platform fee percentage as constructor argument
      const platformFeePercent = 5; // 5% platform fee
      contract = await Contract.deploy(platformFeePercent);
    } else if (contractName === "MentoraToken") {
      // MentoraToken has no constructor arguments
      contract = await Contract.deploy();
    } else {
      // Other contracts don't need constructor arguments
      contract = await Contract.deploy();
    }

    // Wait for deployment to be mined
    await contract.waitForDeployment();
    const address = await contract.getAddress();

    console.log(`${contractName} deployed to:`, address);

    // Wait for a few blocks to ensure the deployment is confirmed
    console.log("Waiting for confirmations...");
    const deploymentTx = contract.deploymentTransaction();
    await deploymentTx.wait(5);

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
      // Deploy all contracts
      const contractsDir = path.join(__dirname, "..", "contracts");
      const contractFiles = fs.readdirSync(contractsDir)
        .filter(file => file.endsWith('.sol'));

      for (const contractFile of contractFiles) {
        const contractName = contractFile.replace('.sol', '');
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