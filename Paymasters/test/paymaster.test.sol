// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/Paymaster.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/core/EntryPoint.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PaymasterValidateTest is Test {
    using ECDSA for bytes32;

    Paymaster public paymaster;
    address public owner;
    address public verifyingSigner;
    IEntryPoint public entryPoint;
    uint256 public signerPrivateKey;

    function setUp() public {
        owner = makeAddr("owner");
        vm.deal(owner, 10 ether);

        signerPrivateKey = 0x7122a8fea1fcd0f0a442a58eb7858e483cdf6de1410b31eccfaacb7d6995e07c;
        verifyingSigner = vm.addr(signerPrivateKey);

        entryPoint = new EntryPoint();

        vm.startPrank(owner);
        paymaster = new Paymaster(entryPoint, verifyingSigner, owner);
        vm.stopPrank();
    }

    function createMockUserOp()
        internal
        view
        returns (PackedUserOperation memory)
    {
        address sender = address(0x1234);
        bytes memory initCode = new bytes(0);
        bytes memory callData = new bytes(0);
        uint256 nonce = 0;
        bytes32 accountGasLimits = bytes32(
            abi.encode(uint128(2000000), uint128(2000000))
        );
        uint256 preVerificationGas = 21000;
        bytes32 gasFees = bytes32(
            abi.encode(uint128(100 gwei), uint128(100 gwei))
        );
        bytes memory paymasterAndData = createValidPaymasterAndData(
            100000000000,
            0,
            uint128(1234),
            true,
            PackedUserOperation({
                sender: sender,
                nonce: nonce,
                initCode: initCode,
                callData: callData,
                accountGasLimits: accountGasLimits,
                preVerificationGas: preVerificationGas,
                gasFees: gasFees,
                paymasterAndData: new bytes(0),
                signature: new bytes(0)
            })
        );

        console.logBytes(paymasterAndData);

        bytes memory signature = new bytes(0);

        return
            PackedUserOperation({
                sender: sender,
                nonce: nonce,
                initCode: initCode,
                callData: callData,
                accountGasLimits: accountGasLimits,
                preVerificationGas: preVerificationGas,
                gasFees: gasFees,
                paymasterAndData: paymasterAndData,
                signature: signature
            });
    }

    function createValidPaymasterAndData(
        uint48 validUntil,
        uint48 validAfter,
        uint128 sponsorUUID,
        bool allowAnyBundler,
        PackedUserOperation memory userOp
    ) internal view returns (bytes memory) {
        Paymaster.PaymasterData memory pmData = Paymaster.PaymasterData({
            validUntil: validUntil,
            validAfter: validAfter,
            sponsorUUID: sponsorUUID,
            allowAnyBundler: allowAnyBundler
        });

        bytes32 hash = paymaster.getHash(userOp, pmData);
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            ethSignedHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);
        // console.logBytes(signature);
        return
            abi.encodePacked(
                bytes6(validUntil),
                bytes6(validAfter),
                bytes16(sponsorUUID),
                allowAnyBundler ? bytes1(0x01) : bytes1(0x00),
                signature
            );
    }

    function testValidSignature() public {
        PackedUserOperation memory userOp = createMockUserOp();

        uint48 validUntil = uint48(block.timestamp + 1 hours);
        uint48 validAfter = uint48(block.timestamp);
        uint128 sponsorUUID = 12345;
        bool allowAnyBundler = true;

        bytes memory paymasterAndData = createValidPaymasterAndData(
            validUntil,
            validAfter,
            sponsorUUID,
            allowAnyBundler,
            userOp
        );

        userOp.paymasterAndData = abi.encodePacked(
            address(paymaster),
            paymasterAndData
        );

        // call the entrypoint to send the transaction
        vm.prank(address(entryPoint));
        (bytes memory context, uint256 validationData) = paymaster
            .validatePaymasterUserOp(userOp, bytes32(0), 0);
        vm.stopPrank();

        // Verify context data
        (address contextSender, uint128 contextUUID) = abi.decode(
            context,
            (address, uint128)
        );
        assertEq(contextSender, userOp.sender);
        assertEq(contextUUID, sponsorUUID);

        // Verify validation timestamps
        assertEq(uint48(validationData >> 160), validUntil);
        assertEq(uint48(validationData >> 208), validAfter);
    }

    // signed with another private key
    function testInvalidSignature() public {
        PackedUserOperation memory userOp = createMockUserOp();

        uint256 wrongPrivateKey = 0x5678;
        uint48 validUntil = uint48(block.timestamp + 1 hours);
        uint48 validAfter = uint48(block.timestamp);

        Paymaster.PaymasterData memory pmData = Paymaster.PaymasterData({
            validUntil: validUntil,
            validAfter: validAfter,
            sponsorUUID: 12345,
            allowAnyBundler: true
        });

        bytes32 hash = paymaster.getHash(userOp, pmData);
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            wrongPrivateKey,
            ethSignedHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory paymasterAndData = abi.encodePacked(
            bytes6(validUntil),
            bytes6(validAfter),
            bytes16(pmData.sponsorUUID),
            pmData.allowAnyBundler ? bytes1(0x01) : bytes1(0x00),
            signature
        );

        userOp.paymasterAndData = abi.encodePacked(
            address(paymaster),
            paymasterAndData
        );

        vm.prank(address(entryPoint));
        vm.expectRevert("VerifyingPaymaster: invalid signature");
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);
    }

    function testInvalidSignatureLength() public {
        PackedUserOperation memory userOp = createMockUserOp();

        bytes memory invalidSignature = new bytes(63); // Invalid length (should be 64 or 65)
        bytes memory paymasterAndData = abi.encodePacked(
            bytes6(uint48(block.timestamp + 1 hours)),
            bytes6(uint48(block.timestamp)),
            bytes16(uint128(12345)),
            bytes1(0x01),
            invalidSignature
        );

        userOp.paymasterAndData = abi.encodePacked(
            address(paymaster),
            paymasterAndData
        );

        vm.prank(address(entryPoint));
        vm.expectRevert(
            "VerifyingPaymaster: invalid signature length in paymasterAndData"
        );
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);
    }

    function testExpiredValidation() public {
        PackedUserOperation memory userOp = createMockUserOp();

        // Set validUntil to a past timestamp
        uint48 validUntil = uint48(block.timestamp - 1 hours);
        uint48 validAfter = uint48(block.timestamp - 2 hours);
        uint128 sponsorUUID = 12345;
        bool allowAnyBundler = true;

        bytes memory paymasterAndData = createValidPaymasterAndData(
            validUntil,
            validAfter,
            sponsorUUID,
            allowAnyBundler,
            userOp
        );

        userOp.paymasterAndData = abi.encodePacked(
            address(paymaster),
            paymasterAndData
        );

        vm.prank(address(entryPoint));
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(
            userOp,
            bytes32(0),
            0
        );

        // The validationData should indicate that the operation is expired
        assertTrue(
            uint48(validationData >> 160) < block.timestamp,
            "Validation should be expired"
        );
    }

    function testFutureValidation() public {
        PackedUserOperation memory userOp = createMockUserOp();

        // Set validAfter to a future timestamp
        uint48 validUntil = uint48(block.timestamp + 2 hours);
        uint48 validAfter = uint48(block.timestamp + 1 hours);
        uint128 sponsorUUID = 12345;
        bool allowAnyBundler = true;

        bytes memory paymasterAndData = createValidPaymasterAndData(
            validUntil,
            validAfter,
            sponsorUUID,
            allowAnyBundler,
            userOp
        );

        userOp.paymasterAndData = abi.encodePacked(
            address(paymaster),
            paymasterAndData
        );

        vm.prank(address(entryPoint));
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(
            userOp,
            bytes32(0),
            0
        );

        // The validationData should indicate that the operation is not yet valid
        assertTrue(
            uint48(validationData >> 208) > block.timestamp,
            "Validation should be in future"
        );
    }

    // function testHardcodedPmData() public {
    //     ////////////////////////////// 0x00174876e800000000000000000000000000000000000000000004d2019a03514f7ccc9696ee37405ce4cf072e94dc37e3ba59fe8dbda10b1178f407e23c21ecbd03bf64f5028b2cb877394708124fc67f51a30adcc6e82dfb46735e2d1b
    //     bytes
    //         memory paymasterAndData = "0x0000674dd4b70000674dd70f0000000000000000000000003ade68b1013847c142f31cc6c6aeec1605d439e78cec6985f93bf5af9db756e72ad11cacd9417ee3ab868342718c9a034bb80bb4123305129ffde2b058a9447cd2ee2f39ad1b";

    //     PackedUserOperation memory userOp = createMockUserOp();

    //     uint48 validUntil = uint48(block.timestamp + 1 hours);
    //     uint48 validAfter = uint48(block.timestamp);
    //     uint128 sponsorUUID = 12345;
    //     bool allowAnyBundler = true;

    //     userOp.paymasterAndData = abi.encodePacked(
    //         address(paymaster),
    //         paymasterAndData
    //     );

    //     // call the entrypoint to send the transaction
    //     vm.prank(address(entryPoint));
    //     (bytes memory context, uint256 validationData) = paymaster
    //         .validatePaymasterUserOp(userOp, bytes32(0), 0);
    //     vm.stopPrank();

    //     // Verify context data
    //     (address contextSender, uint128 contextUUID) = abi.decode(
    //         context,
    //         (address, uint128)
    //     );
    //     assertEq(contextSender, userOp.sender);
    //     assertEq(contextUUID, sponsorUUID);

    //     // Verify validation timestamps
    //     assertEq(uint48(validationData >> 160), validUntil);
    //     assertEq(uint48(validationData >> 208), validAfter);
    // }

    receive() external payable {}
}
