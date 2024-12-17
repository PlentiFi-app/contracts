// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PlentiFiFactory} from "./PlentiFiFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title PlentiFiOpenAccountFactory
 * @notice Factory contract for creating and managing PlentiFi accounts using proxy pattern. This implementation is reserved
 * for trusted signers to deploy accounts.
 * @dev Uses CREATE2 for deterministic address generation and ERC1967 proxy pattern. Then update their implementation
 * using the ImplementationManager contract.
 */
contract PlentiFiAccountFactory is PlentiFiFactory, Ownable {
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;

    string public constant versionId = "PlentiFi-AccountFactory-v0.0.1";
    address public backupOwner;
    uint256 public constant BACKUP_DELAY = 3 days;
    uint256 public backupOwnershipClaimTime;
    bool public isPaused;

    /// @dev Address of the trusted signer that validates operations
    mapping(address => bool) public approvedSigners;

    error BackupOwnershipClaimNotInitiated();
    error InvalidAuthorizationData();
    error BackupOwnerZeroAddress();
    error BackupDelayNotElapsed();
    error NotBackupOwner();

    event BackupOwnerUpdated(address indexed newBackupOwner);
    event BackupOwnershipClaimStarted(uint256 effectiveTime);
    event SignerAdded(address indexed signer);

    /**
     * @notice Constructor to initialize the factory
     * @param implementationManager_ Address of the implementation manager
     * @param id_ Identifier for special purpose factories. Canonical factory id is bytes32(0)
     * @param firstOwner - Address of the first owner
     * @param backupOwner_ - Address of the backup owner
     * @param signersToEnable - Array of signers to enable
     */
    constructor(
        address implementationManager_,
        bytes32 id_,
        address firstOwner,
        address backupOwner_,
        address[] memory signersToEnable
    )
        // transfer ownership to firstOwner at the end of the constructor
        // so we can call "_transferOwnership"
        PlentiFiFactory(implementationManager_, id_)
        Ownable(msg.sender)
    {
        if (backupOwner_ == address(0)) revert BackupOwnerZeroAddress();
        backupOwner = backupOwner_;
        for (uint256 i = 0; i < signersToEnable.length; i++) {
            approvedSigners[signersToEnable[i]] = true;
        }
        emit BackupOwnerUpdated(backupOwner_);

        setSignersBatch(signersToEnable, new bool[](signersToEnable.length));

        _transferOwnership(firstOwner);
    }

    function setPaused(bool paused) external onlyOwner {
        isPaused = paused;
    }

    /**
     * @notice Creates a new account with specified initialization data
     * @notice Only the salt influences the address of the deployed account
     * @notice If the account already exists, the function will return the existing account address
     *
     * @param initData - Initialization data for the account
     * @param salt - Unique salt for address generation
     *
     * @return address - The address of the deployed or existing account
     */
    function createAccount(
        bytes calldata authorizationData,
        bytes calldata initData,
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

        // allow account creation only if the factory is not paused
        if (isPaused) {
            revert("Factory is paused");
        }

        // else verify the authorizationData
        if (!isDeploymentApproved(authorizationData, salt))
            revert InvalidAuthorizationData();

        return _createAccount(initData, salt);
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
            validFrom <= block.timestamp && validUntil >= block.timestamp,
            "Invalid validity period"
        );

        bytes32 hash = _getHash(salt, validFrom, validUntil)
            .toEthSignedMessageHash();

        address signer = ECDSA.recover(hash, signature);

        // return true if the signer is approved or is the owner
        return approvedSigners[signer] || signer == owner();
    }

    /**
     * @dev Sets the approval status of a signer
     * @param signer Address of the signer
     * @param status Approval status
     */
    function setSigner(address signer, bool status) external onlyOwner {
        approvedSigners[signer] = status;
        emit SignerAdded(signer);
    }

    /**
     * @dev Sets the approval status of a list of signers
     * @param signers Array of signer addresses
     * @param status Approval status
     */
    function setSignersBatch(
        address[] memory signers,
        bool[] memory status
    ) public onlyOwner {
        for (uint256 i = 0; i < signers.length; i++) {
            approvedSigners[signers[i]] = status[i];
            emit SignerAdded(signers[i]);
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

    /* -------------------BACKUP FUNCTIONS------------------- */
    // Allow backup owner to claim ownership after delay
    function initiateBackupOwnershipClaim() external {
        if (msg.sender != backupOwner) revert NotBackupOwner();
        backupOwnershipClaimTime = block.timestamp + BACKUP_DELAY;
        emit BackupOwnershipClaimStarted(backupOwnershipClaimTime);
    }

    function claimBackupOwnership() external {
        if (msg.sender != backupOwner) revert NotBackupOwner();
        if (backupOwnershipClaimTime == 0)
            revert BackupOwnershipClaimNotInitiated();
        if (block.timestamp < backupOwnershipClaimTime)
            revert BackupDelayNotElapsed();
        _transferOwnership(backupOwner);
        backupOwnershipClaimTime = 0;
    }
}
