# Deployment Instructions

To deploy the accounts:

1. Rename `.env.example` to `.env` and fill in the required fields.

2. Install Foundry if you haven't already:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

3. Install dependencies:
```bash
forge install
```

4. Preview computed addresses:
```bash
forge script script/hardhat/preview_deployed_addresses.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```

5. Deploy the Implementation Manager:
```bash
forge script script/hardhat/deployImplementationManagerDeterministic.s.sol --broadcast  --rpc-url <your_rpc_url>  --private-key <your_private_key>
```

6. Deploy the Factory Staker:
```bash
# Note: This doesn't need to be deterministic
forge script script/hardhat/deployFactoryStakerDeterministic.s.sol --broadcast --rpc-url <your_rpc_url>  --private-key <your_private_key>
```

7. Deploy your Account Factory:
```bash
forge script script/hardhat/deployAccountFactoryDeterministic.s.sol --broadcast --rpc-url <your_rpc_url>  --private-key <your_private_key>
```

### If not already done:

8. Deploy Kernel:
```bash
forge script script/hardhat/deployKernel.s.sol --broadcast --rpc-url <your_rpc_url>  --private-key <your_private_key>
```

9. Deploy the ProxyUpgrader:
```bash
forge script script/hardhat/deployProxyUpgrader.s.sol --broadcast --rpc-url <your_rpc_url>  --private-key <your_private_key>
```

10. Initialize ImplementationManager and register Account Factory:
```bash
forge script script/postDeployment.s.sol --broadcast --rpc-url <your_rpc_url>  --private-key <your_private_key>
```

### Additional Options

- To verify all transactions before broadcasting, add `--verify` to the forge commands
- To see detailed gas usage, add `--gas-report`
- For testnet deployments, add your private key: `--private-key <your_private_key>`
- For production deployments, use a keystore file instead: `--keystore /path/to/keystore`
