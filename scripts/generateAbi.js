const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

async function main() {
  try {
    // Compile all contracts
    console.log('Compiling contracts...');
    execSync('npx hardhat compile', { stdio: 'inherit' });

    // Create abis directory if it doesn't exist
    const abisDir = path.join(__dirname, '..', 'abis');
    if (!fs.existsSync(abisDir)) {
      fs.mkdirSync(abisDir);
    }

    // Get all contract files from the contracts directory
    const contractsDir = path.join(__dirname, '..', 'contracts');
    const contractFiles = fs.readdirSync(contractsDir)
      .filter(file => file.endsWith('.sol'));

    // Process each contract
    for (const contractFile of contractFiles) {
      const contractName = contractFile.replace('.sol', '');
      const artifactPath = path.join(__dirname, '..', 'artifacts', 'contracts', contractFile, `${contractName}.json`);
      
      if (fs.existsSync(artifactPath)) {
        const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
        const abi = artifact.abi;

        // Write the ABI to a file
        const abiPath = path.join(abisDir, `${contractName}.json`);
        fs.writeFileSync(abiPath, JSON.stringify(abi, null, 2));
        console.log(`Generated ABI for ${contractName} at ${abiPath}`);
      } else {
        console.warn(`No artifact found for ${contractName}`);
      }
    }

    console.log('ABI generation completed successfully');
  } catch (error) {
    console.error('Error generating ABIs:', error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 