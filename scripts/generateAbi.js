const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

async function main() {
  try {
    // Compile the contracts
    console.log('Compiling contracts...');
    execSync('npx hardhat compile', { stdio: 'inherit' });

    // Read the compiled contract artifact
    const artifactPath = path.join(__dirname, '..', 'artifacts', 'contracts', 'Mentora.sol', 'Mentora.json');
    const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));

    // Extract the ABI
    const abi = artifact.abi;

    // Create abis directory if it doesn't exist
    const abisDir = path.join(__dirname, '..', 'abis');
    if (!fs.existsSync(abisDir)) {
      fs.mkdirSync(abisDir);
    }

    // Write the ABI to a file
    const abiPath = path.join(abisDir, 'Mentora.json');
    fs.writeFileSync(abiPath, JSON.stringify(abi, null, 2));

    console.log(`ABI generated successfully at ${abiPath}`);
  } catch (error) {
    console.error('Error generating ABI:', error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 