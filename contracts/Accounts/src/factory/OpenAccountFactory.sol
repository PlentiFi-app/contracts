// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PlentiFiFactory} from "./PlentiFiFactory.sol";

/**
 * @title PlentiFiOpenAccountFactory
 * @notice Factory contract for creating and managing PlentiFi accounts using proxy pattern. This implementation is open
 * so anyone can deploy their own account. BE CAREFUL, anyone can deploy an account with the same salt and get the same address on another chain
 * @dev Uses CREATE2 for deterministic address generation and ERC1967 proxy pattern. Then update their implementation
 * using the ImplementationManager contract.
 */
contract PlentiFiOpenAccountFactory is PlentiFiFactory {
    string public constant versionId = "PlentiFi-OpenAccountFactory-v0.0.1";

    /**
     * @notice Constructor to initialize the factory
     * @param implementationManager_ Address of the implementation manager
     * @param id_ Identifier for special purpose factories. Canonical factory id is bytes32(0)
     */
    constructor(
        address implementationManager_,
        bytes32 id_
    ) PlentiFiFactory(implementationManager_, id_) {}

    /**
     * @notice Creates a new account with specified initialization data
     * @notice Only the salt influences the address of the deployed account
     * @notice If the account already exists, the function will return the existing account address
     *
     * @param data - Initialization data for the account
     * @param salt - Unique salt for address generation
     *
     * @return address - The address of the deployed or existing account
     */
    function createAccount(
        bytes calldata data,
        bytes32 salt
    ) external payable returns (address) {
        address addr = getAddress(salt);

        uint32 size;
        assembly {
            size := extcodesize(addr)
        }

        // If there's already a contract, return its address
        if (size > 0) {
            return addr;
        }

        return _createAccount(data, salt);
    }
}
