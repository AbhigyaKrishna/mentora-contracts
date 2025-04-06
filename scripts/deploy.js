const hre = require("hardhat");
const path = require("path");
const fs = require("fs");

async function main() {
  try {
    console.log("Starting deployment process...");

    // Get all contract files from the contracts directory
    const contractsDir = path.join(__dirname, "..", "contracts");
    const contractFiles = fs.readdirSync(contractsDir)
      .filter(file => file.endsWith('.sol'));

    // Process each contract
    for (const contractFile of contractFiles) {
      const contractName = contractFile.replace('.sol', '');
      console.log(`\nDeploying ${contractName}...`);

      try {
        // Get the contract factory
        const Contract = await hre.ethers.getContractFactory(contractName);
        
        // Deploy the contract
        const contract = await Contract.deploy();
        await contract.deployed();

        console.log(`${contractName} deployed to:`, contract.address);

        // Wait for a few blocks to ensure the deployment is confirmed
        console.log("Waiting for confirmations...");
        await contract.deployTransaction.wait(5);

        // Save deployment info
        const deploymentsDir = path.join(__dirname, "..", "deployments");
        if (!fs.existsSync(deploymentsDir)) {
          fs.mkdirSync(deploymentsDir);
        }

        const deploymentInfo = {
          contractName: contractName,
          address: contract.address,
          network: hre.network.name,
          deployer: contract.deployTransaction.from,
          blockNumber: contract.deployTransaction.blockNumber,
          timestamp: new Date().toISOString()
        };

        const deploymentPath = path.join(deploymentsDir, `${contractName}-${hre.network.name}.json`);
        fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
        console.log(`Deployment info saved to: ${deploymentPath}`);

      } catch (error) {
        console.error(`Error deploying ${contractName}:`, error);
        // Continue with next contract even if one fails
        continue;
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