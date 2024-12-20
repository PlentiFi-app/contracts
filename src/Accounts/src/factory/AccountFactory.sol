// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PlentiFiFactory} from "./PlentiFiFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title PlentiFiAccountFactory
 * @notice Factory contract for creating and managing PlentiFi accounts using proxy pattern
 * @dev Modified to use block numbers instead of timestamps to comply with ERC-4337 requirements
 * This implementation is reserved for trusted signers to deploy accounts
 */
contract PlentiFiAccountFactory is PlentiFiFactory, Ownable {
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;

    /// @notice Version identifier for the contract
    string public constant versionId = "PlentiFi-AccountFactory-v0.0.1";

    /// @notice Address that can claim ownership after delay in emergency situations
    address public backupOwner;

    /// @notice Delay period after which backup owner can claim ownership
    uint256 public constant BACKUP_DELAY = 2 days;

    /// @notice Timestamp initiating the backup ownership claim process
    uint256 public backupOwnershipClaim = 0;

    /// @notice Emergency pause switch for account creation
    bool public isPaused;

    /// @notice Mapping of addresses approved to authorize account deployments
    mapping(address => bool) public approvedSigners;

    // Custom errors
    error BackupOwnershipClaimNotInitiated();
    error InvalidAuthorizationData();
    error BackupOwnerZeroAddress();
    error BackupDelayNotElapsed();
    error NotBackupOwner();

    // Events
    event BackupOwnerUpdated(address indexed newBackupOwner);
    event BackupOwnershipClaimStarted(uint256 effectiveBlock);
    event SignerAdded(address indexed signer);

    /**
     * @notice Initializes the factory with core parameters
     * @param implementationManager_ Address of the implementation manager contract
     * @param id_ Identifier for special purpose factories (canonical factory uses bytes32(0))
     * @param firstOwner Address that will own this factory contract
     * @param backupOwner_ Address that can claim ownership in emergency situations
     * @param signersToEnable Initial list of approved signers
     */
    constructor(
        address implementationManager_,
        bytes32 id_,
        address firstOwner,
        address backupOwner_,
        address[] memory signersToEnable
    ) PlentiFiFactory(implementationManager_, id_) Ownable(msg.sender) {
        if (backupOwner_ == address(0)) revert BackupOwnerZeroAddress();
        backupOwner = backupOwner_;
        for (uint256 i = 0; i < signersToEnable.length; i++) {
            approvedSigners[signersToEnable[i]] = true;
        }
        emit BackupOwnerUpdated(backupOwner_);

        setSignersBatch(signersToEnable, new bool[](signersToEnable.length));

        _transferOwnership(firstOwner);
    }

    /**
     * @notice Allows owner to pause/unpause account creation
     * @param paused New pause state
     */
    function setPaused(bool paused) external onlyOwner {
        isPaused = paused;
    }

    /**
     * @notice Creates a new account or returns existing account address
     * @dev Uses CREATE2 for deterministic address generation
     * @param authorizationData Signature and validity data authorizing the deployment
     * @param initData Initialization data for the new account
     * @param salt Unique value for address generation
     * @return address of the deployed or existing account
     */
    function createAccount(
        bytes calldata authorizationData,
        bytes calldata initData,
        bytes32 salt
    ) external payable returns (address) {
        address addr = getAddress(salt);

        // Check if account already exists
        uint32 size;
        assembly {
            size := extcodesize(addr)
        }

        if (size > 0) {
            return addr;
        }

        if (isPaused) {
            revert("Factory is paused");
        }

        if (!isDeploymentApproved(authorizationData, salt))
            revert InvalidAuthorizationData();

        return _createAccount(initData, salt);
    }

    /**
     * @notice Verifies if the deployment is authorized by an approved signer
     * @dev Checks signature validity and block number bounds
     * @param authorizationSig Authorization signature
     * @param salt Deployment salt value
     * @return bool indicating if deployment is approved
     */
    function isDeploymentApproved(
        bytes calldata authorizationSig,
        bytes32 salt
    ) internal view returns (bool) {
        bytes32 hash = _getHash(salt).toEthSignedMessageHash();

        address signer = ECDSA.recover(hash, authorizationSig);

        // return true if the signer is approved or is the owner
        return approvedSigners[signer] || signer == owner();
    }

    /**
     * @notice Adds or removes a single approved signer
     * @param signer Address to modify
     * @param status New approval status
     */
    function setSigner(address signer, bool status) external onlyOwner {
        approvedSigners[signer] = status;
        emit SignerAdded(signer);
    }

    /**
     * @notice Batch updates approved signers
     * @param signers Array of addresses to modify
     * @param status Array of approval statuses
     */
    function setSignersBatch(
        address[] memory signers,
        bool[] memory status
    ) public onlyOwner {
        uint256 len = signers.length;
        for (uint256 i = 0; i < len; i++) {
            approvedSigners[signers[i]] = status[i];
            emit SignerAdded(signers[i]);
        }
    }

    /**
     * @notice Computes the message hash for authorization
     * @param salt Deployment salt
     */
    function _getHash(bytes32 salt) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(ID, address(this), salt, block.chainid)
            );
    }

    /**
     * @notice Starts the process of backup owner claiming ownership
     * @dev Sets the block number after which backup owner can claim ownership
     */
    function initiateBackupOwnershipClaim() external {
        if (msg.sender != backupOwner) revert NotBackupOwner();
        backupOwnershipClaim = block.timestamp + BACKUP_DELAY;
        emit BackupOwnershipClaimStarted(backupOwnershipClaim);
    }

    /**
     * @notice Allows backup owner to claim ownership after delay period
     * @dev Can only be called after delay period and claim initiation
     */
    function claimBackupOwnership() external {
        if (msg.sender != backupOwner) revert NotBackupOwner();
        if (backupOwnershipClaim == 0)
            revert BackupOwnershipClaimNotInitiated();
        if (block.timestamp < backupOwnershipClaim)
            revert BackupDelayNotElapsed();
        _transferOwnership(backupOwner);
        backupOwnershipClaim = 0;
    }
}
