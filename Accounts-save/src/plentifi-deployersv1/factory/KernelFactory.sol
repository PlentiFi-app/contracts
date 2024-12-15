// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
// import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";
import {ERC1967Proxy} from "openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IImplementationManager} from "../interfaces/IImplementationManager.sol";
import {Create2} from "openzeppelin/contracts/utils/Create2.sol";
import {FirstImplementation} from "../FirstImplementation.sol";
import {ProxyUpgrader} from "../ProxyUpgrader.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {ECDSA} from "openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import {MessageHashUtils} from "openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "solady/auth/Ownable.sol";

/**
 * @title PlentiFiOpenAccountFactory
 * @notice Factory contract for creating and managing PlentiFi accounts using proxy pattern. This implementation is reserved for
 * the PlentiFi application: each deployment requires an authorization signature.
 * @dev Uses CREATE2 for deterministic address generation and ERC1967 proxy pattern. Then update their implementation
 * using the ImplementationManager contract.
 */
contract PlentiFiAccountFactory is Ownable {
    using ECDSA for bytes32;
    // using MessageHashUtils for bytes32;

    error InvalidImplementationManager();
    error InvalidAuthorizationData();
    error DeploymentFailed();
    error InitializeError();
    error ZeroAddress();

    string public constant versionId = "PlentiFi-OpenAccountFactory-v0.0.1";
    FirstImplementation public immutable firstImplementation;
    IImplementationManager public immutable implementationManager;

    // the custom identifier for special purpose factories
    bytes32 public immutable ID;

    /// @dev Address of the trusted signer that validates operations
    mapping(address => bool) public approvedSigners;

    event AccountDeployed(address indexed account, bytes32 salt);

    /**
     * @notice Constructor to initialize the factory
     * @param implementationManager_ Address of the implementation manager
     * @param id_ Identifier for special purpose factories. Canonical factory id is bytes32(1)
     */
    constructor(
        address implementationManager_,
        bytes32 id_,
        address firstOwner
    ) {
        if (implementationManager_ == address(0)) revert ZeroAddress();
        transferOwnership(firstOwner);
        implementationManager = IImplementationManager(implementationManager_);
        firstImplementation = new FirstImplementation();
        ID = id_;
    }

    /**
     * @notice Creates a new account with specified initialization data
     * @param authorizationData Authorization data for the account
     * @param data Initialization data for the account
     * @param salt Unique salt for address generation
     * @return address The address of the deployed or existing account
     *
     * @dev The deployed account address only depends on the salt and the factory address
     */
    function createAccount(
        bytes calldata authorizationData,
        bytes calldata data,
        bytes32 salt
    ) public payable returns (address) {
        address addr = getAddress(bytes("0x00"), salt);

        uint32 size;
        assembly {
            size := extcodesize(addr)
        }

        // If there's already a contract, return its address
        if (size > 0) {
            return addr;
        }

        // else verify the authorizationData
        if (!isDeploymentApproved(authorizationData, salt))
            revert InvalidAuthorizationData();

        try
            new ERC1967Proxy{salt: salt, value: msg.value}(
                address(firstImplementation),
                ""
            )
        returns (ERC1967Proxy proxy) {
            address newImplementation = implementationManager.implementation();
            address proxyAddress = address(proxy);

            // upgrade to the last available implementation and initialize
            ProxyUpgrader(implementationManager.proxyUpgrader()).upgrade(
                proxyAddress,
                newImplementation,
                data
            );

            emit AccountDeployed(proxyAddress, salt);

            return proxyAddress;
        } catch {
            revert DeploymentFailed();
        }
    }

    /**
     * @notice Computes the counterfactual address for an account
     * @param salt Salt for address generation
     * @return The computed address
     */
    function getAddress(
        // kept to match the usual kernel factory interface and avoid issues with its sdk
        bytes memory,
        bytes32 salt
    ) public view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(address(firstImplementation), "")
        );

        return Create2.computeAddress(salt, keccak256(bytecode), address(this));
    }

    /**
     * @notice Wrapper function for ethers compatibility
     * @param salt Salt for address generation
     * @return The computed address
     *
     * when trying to call getAddress using ethers,
     * it returns the contract addres (because of the ethers' built-in function)
     * so we need to wrap the function to get the address
     */
    function getAddressWrapper(bytes32 salt) external view returns (address) {
        return getAddress("", salt);
    }

    /**
     * @notice Verifies the authorization data: decode the signature and verify if the signer is approved
     * @param authorizationData The authorization data to verify
     * @param salt The salt for the deployment
     */
    function isDeploymentApproved(
        bytes calldata authorizationData,
        bytes32 salt
    ) internal view returns (bool) {
        (bytes memory signature, uint48 validFrom, uint48 validUntil) = abi
            .decode(authorizationData, (bytes, uint48, uint48));

        require(
            signature.length == 64 || signature.length == 65,
            "KernelFactory: invalid auth signature length"
        );

        require(
            validFrom <= block.timestamp && validUntil >= block.timestamp,
            "KernelFactory: invalid auth validity period"
        );

        bytes32 hash = _getHash(salt, validFrom, validUntil)
            .toEthSignedMessageHash();

        return approvedSigners[ECDSA.recover(hash, signature)];
    }

    /**
     * @dev Sets the approval status of a signer
     * @param signer Address of the signer
     * @param status Approval status
     */
    function setSigners(address signer, bool status) external onlyOwner {
        approvedSigners[signer] = status;
    }

    /**
     * @dev Sets the approval status of a list of signers
     * @param signers Array of signer addresses
     * @param status Approval status
     */
    function setSignersBatch(
        address[] calldata signers,
        bool[] calldata status
    ) external onlyOwner {
        for (uint256 i = 0; i < signers.length; i++) {
            approvedSigners[signers[i]] = status[i];
        }
    }

    /**
     * @notice Computes the hash for the authorization data
     * @param salt The salt for the deployment
     * @param validFrom The valid from timestamp
     * @param validUntil The valid until timestamp
     * @return The computed hash
     */
    function _getHash(
        bytes32 salt,
        uint48 validFrom,
        uint48 validUntil
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(ID, salt, validFrom, validUntil, block.chainid)
            );
    }
}
