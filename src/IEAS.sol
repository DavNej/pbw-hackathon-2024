// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Signature} from "./Common.sol";

/// @notice A struct representing a single attestation.
struct Attestation {
    bytes32 uid; // A unique identifier of the attestation.
    bytes32 schema; // The unique identifier of the schema.
    uint64 time; // The time when the attestation was created (Unix timestamp).
    uint64 expirationTime; // The time when the attestation expires (Unix timestamp).
    uint64 revocationTime; // The time when the attestation was revoked (Unix timestamp).
    address recipient; // The recipient of the attestation.
    address attester; // The attester/sender of the attestation.
    bool revocable; // Whether the attestation is revocable.
    bytes data; // Custom attestation data.
}

/// @notice A struct representing the arguments of the attestation request.
struct AttestationRequestData {
    address recipient; // The recipient of the attestation.
    uint64 expirationTime; // The time when the attestation expires (Unix timestamp).
    bool revocable; // Whether the attestation is revocable.
    bytes32 refUID; // The UID of the related attestation.
    bytes data; // Custom attestation data.
    uint256 value; // An explicit ETH amount to send to the resolver. This is important to prevent accidental user errors.
}

/// @notice A struct representing the full arguments of the attestation request.
struct AttestationRequest {
    bytes32 schema; // The unique identifier of the schema.
    AttestationRequestData data; // The arguments of the attestation request.
}

/// @notice A struct representing the arguments of the revocation request.
struct RevocationRequestData {
    bytes32 uid; // The UID of the attestation to revoke.
    uint256 value; // An explicit ETH amount to send to the resolver. This is important to prevent accidental user errors.
}

/// @notice A struct representing the full arguments of the revocation request.
struct RevocationRequest {
    bytes32 schema; // The unique identifier of the schema.
    RevocationRequestData data; // The arguments of the revocation request.
}

/// @title IEAS
/// @notice EAS - Ethereum Attestation Service interface.
interface IEAS {
    /// @notice Emitted when an attestation has been made.
    /// @param recipient The recipient of the attestation.
    /// @param attester The attesting account.
    /// @param uid The UID the revoked attestation.
    /// @param schemaUID The UID of the schema.
    event Attested(address indexed recipient, address indexed attester, bytes32 uid, bytes32 indexed schemaUID);

    /// @notice Emitted when an attestation has been revoked.
    /// @param recipient The recipient of the attestation.
    /// @param attester The attesting account.
    /// @param schemaUID The UID of the schema.
    /// @param uid The UID the revoked attestation.
    event Revoked(address indexed recipient, address indexed attester, bytes32 uid, bytes32 indexed schemaUID);

    /// @notice Emitted when a data has been timestamped.
    /// @param data The data.
    /// @param timestamp The timestamp.
    event Timestamped(bytes32 indexed data, uint64 indexed timestamp);

    /// @notice Attests to a specific schema.
    /// @param request The arguments of the attestation request.
    /// @return The UID of the new attestation.
    ///
    /// Example:
    ///     attest({
    ///         schema: "0facc36681cbe2456019c1b0d1e7bedd6d1d40f6f324bf3dd3a4cef2999200a0",
    ///         data: {
    ///             recipient: "0xdEADBeAFdeAdbEafdeadbeafDeAdbEAFdeadbeaf",
    ///             expirationTime: 0,
    ///             revocable: true,
    ///             refUID: "0x0000000000000000000000000000000000000000000000000000000000000000",
    ///             data: "0xF00D",
    ///             value: 0
    ///         }
    ///     })
    function attest(AttestationRequest calldata request) external payable returns (bytes32);

    /// @notice Revokes an existing attestation to a specific schema.
    /// @param request The arguments of the revocation request.
    ///
    /// Example:
    ///     revoke({
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: {
    ///             uid: '0x101032e487642ee04ee17049f99a70590c735b8614079fc9275f9dd57c00966d',
    ///             value: 0
    ///         }
    ///     })
    function revoke(RevocationRequest calldata request) external payable;

    /// @notice Timestamps the specified bytes32 data.
    /// @param data The data to timestamp.
    /// @return The timestamp the data was timestamped with.
    function timestamp(bytes32 data) external returns (uint64);

    /// @notice Returns an existing attestation by UID.
    /// @param uid The UID of the attestation to retrieve.
    /// @return The attestation data members.
    function getAttestation(bytes32 uid) external view returns (Attestation memory);

    /// @notice Checks whether an attestation exists.
    /// @param uid The UID of the attestation to retrieve.
    /// @return Whether an attestation exists.
    function isAttestationValid(bytes32 uid) external view returns (bool);

    /// @notice Returns the timestamp that the specified data was timestamped with.
    /// @param data The data to query.
    /// @return The timestamp the data was timestamped with.
    function getTimestamp(bytes32 data) external view returns (uint64);
}
