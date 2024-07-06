// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19 <0.9.0;

import {SCL_ECDSAB4} from "./SCL/lib/libSCL_ecdsab4.sol";
import {Base64} from "lib/solady/src/utils/Base64.sol";
import {p, a, gx, gy, gpow2p128_x, gpow2p128_y, n} from "./SCL/fields/SCL_secp256r1.sol";
import {SIG_VALIDATION_SUCCESS_UINT, SIG_VALIDATION_FAILED_UINT} from "./constants.sol";

contract SclVerifier {
    error InvalidAuthenticatorData();
    error InvalidClientData();
    error InvalidChallenge();

    function generateMessage(
        bytes1 authenticatorDataFlagMask,
        bytes calldata authenticatorData,
        bytes calldata clientData,
        bytes calldata clientChallenge,
        uint256 clientChallengeOffset
    ) internal pure returns (bytes32 message) {
        unchecked {
            if ((authenticatorData[32] & authenticatorDataFlagMask) == 0)
                revert InvalidAuthenticatorData();
            if (clientChallenge.length == 0) revert InvalidChallenge();
            bytes memory challengeEncoded = bytes(
                Base64.encode(clientChallenge, true, true)
            );
            bytes32 challengeHashed = keccak256(
                clientData[clientChallengeOffset:(clientChallengeOffset +
                    challengeEncoded.length)]
            );
            if (keccak256(challengeEncoded) != challengeHashed)
                revert InvalidClientData();
            message = sha256(
                abi.encodePacked(authenticatorData, sha256(clientData))
            );
        }
    }

    function verify(
        bytes1 authenticatorDataFlagMask,
        bytes calldata authenticatorData,
        bytes calldata clientData,
        bytes calldata clientChallenge,
        uint256 clientChallengeOffset,
        uint256[2] calldata rs,
        uint256[2] calldata publicKey,
        uint[2] calldata q2p128 // precomputed of 2**128.publicKey
    ) external view returns (uint256) {

        unchecked {
            bytes32 message = generateMessage(
                authenticatorDataFlagMask,
                authenticatorData,
                clientData,
                clientChallenge,
                clientChallengeOffset
            );

            uint256[10] memory Q = [
                publicKey[0], // qx
                publicKey[1], // qy
                q2p128[0], // q2p128_x
                q2p128[1], // q2p128_y
                p,
                a,
                gx,
                gy,
                gpow2p128_x,
                gpow2p128_y
            ];

            return
                SCL_ECDSAB4.verify(message, rs[0], rs[1], Q, n)
                    ? SIG_VALIDATION_SUCCESS_UINT
                    : SIG_VALIDATION_FAILED_UINT;
        }
    }
}
