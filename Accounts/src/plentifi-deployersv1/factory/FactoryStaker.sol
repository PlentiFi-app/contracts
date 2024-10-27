// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./KernelFactory.sol";
import "../../kernel/interfaces/IEntryPoint.sol";
import "solady/auth/Ownable.sol";

/**
 * @title PlentiFiFactoryStaker
 * @notice Manages account factory deployments and entrypoint staking operations for PlentiFi
 * @dev Implements factory approval system and EntryPoint staking functionality
 * Derived from the kernel FactoryStaker contract
 */
contract PlentiFiFactoryStaker is Ownable {
    /// @notice Version identifier for the contract
    string public constant versionId = "PlentiFi-StakerFactory-v0.0.1";

    bool public locked;

    mapping(PlentiFiAccountFactory => bool) public approved;

    event StakeWithdrawn(
        address indexed entryPoint,
        address indexed recipient,
        uint256 amount
    );

    error InvalidUnstakeDelay();
    error NotApprovedFactory();
    error ZeroAddress();
    error ZeroValue();
    error Locked();

    /**
     * @notice Contract constructor
     * @param _owner Address of the contract owner
     * @param _locked Initial lock state
     */
    constructor(address _owner, bool _locked) {
        if (_owner == address(0)) revert ZeroAddress();

        _initializeOwner(_owner);
        locked = _locked;
    }

    /**
     * @notice Deploy an account using an approved factory
     * @param factory The account factory to use
     * @param createData Initialization data for the account
     * @param salt Unique identifier for the deployment
     * @return address The address of the deployed account
     */
    function deployWithFactory(
        PlentiFiAccountFactory factory,
        bytes calldata createData,
        bytes32 salt
    ) external payable returns (address) {
        if (!approved[factory]) {
            revert NotApprovedFactory();
        }
        if (locked) {
            revert Locked();
        }

        return factory.createAccount{value: msg.value}(createData, salt);
    }

    /**
     * @notice Approve or revoke a factory's permission
     * @param factory The factory address to modify
     * @param approval New approval status
     */
    function approveFactory(
        PlentiFiAccountFactory factory,
        bool approval
    ) external payable onlyOwner {
        if (address(factory) == address(0)) revert ZeroAddress();

        approved[factory] = approval;
    }

    /**
     * @notice Add stake to the EntryPoint contract
     * @param entryPoint The EntryPoint contract address
     * @param unstakeDelay Time delay for unstaking
     */
    function stake(
        IEntryPoint entryPoint,
        uint32 unstakeDelay
    ) external payable onlyOwner {
        if (address(entryPoint) == address(0)) revert ZeroAddress();
        if (msg.value == 0) revert ZeroValue();
        if (unstakeDelay == 0) revert InvalidUnstakeDelay();

        entryPoint.addStake{value: msg.value}(unstakeDelay);
    }

    /**
     * @notice Initiate stake withdrawal process
     * @param entryPoint The EntryPoint contract address
     */
    function unlockStake(IEntryPoint entryPoint) external payable onlyOwner {
        if (address(entryPoint) == address(0)) revert ZeroAddress();

        entryPoint.unlockStake();
    }

    /**
     * @notice Withdraw unlocked stake to a specified recipient
     * @param entryPoint The EntryPoint contract address
     * @param recipient Address to receive the withdrawn stake
     */
    function withdrawStake(
        IEntryPoint entryPoint,
        address payable recipient
    ) external payable onlyOwner {
        if (address(entryPoint) == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();

        uint256 previousBalance = address(recipient).balance;
        entryPoint.withdrawStake(recipient);
        uint256 withdrawn = address(recipient).balance - previousBalance;

        emit StakeWithdrawn(address(entryPoint), recipient, withdrawn);
    }

    /**
     * @notice Toggle the locked state
     * @dev Only callable by owner
     */
    function toggleLock() external onlyOwner {
        locked = !locked;
    }
}
