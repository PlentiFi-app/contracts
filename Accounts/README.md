
to deploy the accounts:

Rename `.env.example` to `.env` and fill in the required fields.

Then, install the dependencies:
```bash
yarn install
```

Verify the computed addresses match the expected addresses:
```bash
npx hardhat run script/hardhat/preview_deployed_addresses.ts --network <your_evm_network>
```

Deploy the Implementation manager:
```bash
npx hardhat run script/hardhat/deployImplementationManagerDeterministic.ts --network <your_evm_network>
```

Deploy the Factory Staker:
```bash
npx hardhat run script/hardhat/deployFactoryStakerDeterministic.ts --network <your_evm_network>
```

Deploy your Account Factory:
```bash
npx hardhat run script/hardhat/deployAccountFactoryDeterministic.ts --network <your_evm_network>
```

### If not already done:

Deploy Kernel:
```bash
npx hardhat run script/hardhat/deployKernel.ts --network <your_evm_network>
```

Deploy the ProxyUpgrader:
```bash
npx hardhat run script/hardhat/deployProxyUpgrader.ts --network <your_evm_network>
```

Then, you'll need to initialize the ImplementationManager and register the Account Factory in the Factory Staker:
```bash
npx hardhat run script/postDeployment.ts --network <your_evm_network>
```