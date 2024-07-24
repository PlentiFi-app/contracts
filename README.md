# PlentiFi - Smart Contracts - V0.0.1

## Overview
PlentiFi takes advantage of the Account Abstraction feature to provide a clean user experience: **no need to worry about gas fees or managing your private keys**. The Account Abstraction feature allows users to interact with the blockchain without having to pay gas fees. Instead, the dApp pays the fees on behalf of the user. This feature is enabled by the use of a bundler and entryPoint, which are responsible for paying the gas fees on behalf of the user. The bundler is a smart contract that collects gas fees from the dApp and pays them to the network, while the entryPoint is a smart contract that interacts with the bundler to pay the gas fees.
<br>
This repository contains all the PlentiFi smart accounts contracts with their factory along with a simple paymaster.


These contracts are designed to be used in with PlentiFi or any other application which choses to support them <br>
You can find them in the `./src` folder and are organized as follows:
- The **Accounts folder** contains the account factory contract and the account contract. They are used to create and manage user accounts. Anyone can use them, even if they do not use our SDK.
- The **paymaster folder** contains a simple verifying paymaster and a token paymaster to sponsor user's gas fees.
- The **Lib folder** contains the Webauthn library contract and the secp256r1 library. They are used to verify the user's identity through the WebAuthn protocol.
- The **increment** contracts is a simple contract used to test the PlentiFi contracts. 

## Live contracts addresses 📂

No official contracts have been deployed yet. Stay tuned

## 🚀 Installation, Usage, and Contribution Guide

This section explains how to install, use, and contribute to the PlentiFi repository, which includes Solidity contracts.

### Installation

To install and work with the repository, you need to have [Foundry](https://github.com/foundry-rs/foundry) installed. Foundry is a blazing fast, portable, and modular toolkit for Ethereum application development written in Rust.

1. **Install Foundry**

   Follow the instructions in the [Foundry GitHub repository](https://github.com/foundry-rs/foundry) to install Foundry on your machine.

2. **Clone the Repository**

   Clone the PlentiFi repository to your local machine:

   ```sh
   git clone https://github.com/PlentiFi-app/contracts.git
   cd contracts
   ```

3. **Build the Contracts**

   Use Foundry to build the Solidity contracts:

   ```sh
   forge build
   ```

### Usage

After building the contracts, you can deploy them using Foundry's `forge script` command. Here’s how you can deploy the contracts:

1. **Set Up Environment Variables**

   Ensure you have your RPC URL and private key ready. You can set these as environment variables or replace them directly in the command below.

2. **Deploy the Contracts**

   Use the following command to deploy the contracts:

   ```sh
   forge script script/<script file name> --broadcast -vvv --rpc-url <RPC_URL> --private-key <YOUR_PRIVATE_KEY>
   ```

   Replace `<script file name>` with the actual script file name you want to use for deployment. Also, replace `<RPC_URL>` and `<YOUR_PRIVATE_KEY>` with your actual RPC URL and private key.

### Contributing

We welcome contributions to the PlentiFi repository. Here’s how you can contribute:

1. **Fork the Repository**

   Fork the repository to your own GitHub account and clone it to your local machine.

   ```sh
   git clone https://github.com/PlentiFi-app/contracts.git
   cd plentifi
   ```

2. **Create a New Branch**

   Create a new branch for your feature or bug fix.

   ```sh
   git checkout -b feature/new-feature
   ```

3. **Make Your Changes**

   Make your changes to the codebase. Ensure that your changes are well-documented and include tests if applicable.

4. **Commit and Push Your Changes**

   Commit your changes and push them to your fork.

   ```sh
   git add .
   git commit -m "Add new feature"
   git push origin feature/new-feature
   ```

5. **Create a Pull Request**

   Go to the original repository on GitHub and create a pull request from your fork. Provide a clear description of your changes and any additional context that reviewers might need.

By following these steps, you can easily install, use, and contribute to the PlentiFi repository. We appreciate your contributions and look forward to collaborating with you!

