// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./KernelFactory.sol";
import "../../kernel/interfaces/IEntryPoint.sol";
import "solady/auth/Ownable.sol";

contract PlentifiFactoryStaker is Ownable {
    string public constant versionId = "PlentiFi-StakerFactory-v0.0.1";

    bool public locked;

    mapping(PlentiFiAccountFactory => bool) public approved;

    error NotApprovedFactory();
    error Locked();

    constructor(address _owner, bool _locked) {
        _initializeOwner(_owner);
        locked = _locked;
    }

    function deployWithFactory(
        PlentiFiAccountFactory factory,
        bytes calldata createData,
        bytes32 salt
    )
        external
        payable
        returns (
            address
        )
    {
        if (!approved[factory]) {
            revert NotApprovedFactory();
        }
        if(locked) {
            revert Locked();
        }
        
        return factory.createAccount(createData, salt);
    }

    function approveFactory(
        PlentiFiAccountFactory factory,
        bool approval
    ) external payable onlyOwner {
        approved[factory] = approval;
    }

    function stake(
        IEntryPoint entryPoint,
        uint32 unstakeDelay
    ) external payable onlyOwner {
        entryPoint.addStake{value: msg.value}(unstakeDelay);
    }

    function unlockStake(IEntryPoint entryPoint) external payable onlyOwner {
        entryPoint.unlockStake();
    }

    function withdrawStake(
        IEntryPoint entryPoint,
        address payable recipient
    ) external payable onlyOwner {
        entryPoint.withdrawStake(recipient);
    }
}
