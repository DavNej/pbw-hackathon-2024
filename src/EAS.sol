// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {
    AccessDenied, EMPTY_UID, Signature, InvalidLength, NotFound, NO_EXPIRATION_TIME, uncheckedInc
} from "./Common.sol";

import {
    Attestation,
    AttestationRequest,
    AttestationRequestData,
    IEAS,
    RevocationRequest,
    RevocationRequestData
} from "./IEAS.sol";

import {SchemaRecord} from "./SchemaRegistry.sol";
// import {EIP1271Verifier} from "./EIP1271Verifier.sol";

/// @title EAS
/// @notice The Ethereum Attestation Service protocol.
contract EAS is IEAS {
// contract EAS is IEAS, EIP1271Verifier {
    using Address for address payable;

    error AlreadyRevoked();
    error AlreadyTimestamped();
    error InvalidExpirationTime();
    error InvalidRegistry();
    error InvalidSchema();
    error Irrevocable();

    /// @notice A struct representing an internal attestation result.
    struct AttestationsResult {
        uint256 usedValue; // Total ETH amount that was sent to resolvers.
        bytes32[] uids; // UIDs of the new attestations.
    }

    // The global schema registry.
    SchemaRegistry private immutable _schemaRegistry;

    // The global mapping between attestations and their UIDs.
    mapping(bytes32 uid => Attestation attestation) private _db;

    // The global mapping between data and their timestamps.
    mapping(bytes32 data => uint64 timestamp) private _timestamps;

    // The global mapping between data and their revocation timestamps.
    mapping(address revoker => mapping(bytes32 data => uint64 timestamp) timestamps) private _revocationsOffchain;

    /// @dev Creates a new EAS instance.
    /// @param registry The address of the global schema registry.
    constructor(ISchemaRegistry registry) EIP1271Verifier("EAS", "1.3.0") {
        if (address(registry) == address(0)) {
            revert InvalidRegistry();
        }

        _schemaRegistry = registry;
    }

    /// @inheritdoc IEAS
    function getSchemaRegistry() external view returns (ISchemaRegistry) {
        return _schemaRegistry;
    }

    /// @inheritdoc IEAS
    function attest(AttestationRequest calldata request) external payable returns (bytes32) {
        AttestationRequestData[] memory data = new AttestationRequestData[](1);
        data[0] = request.data;

        return _attest(request.schema, data, msg.sender, msg.value, true).uids[0];
    }

    /// @inheritdoc IEAS
    function revoke(RevocationRequest calldata request) external payable {
        RevocationRequestData[] memory data = new RevocationRequestData[](1);
        data[0] = request.data;

        _revoke(request.schema, data, msg.sender, msg.value, true);
    }

    /// @inheritdoc IEAS
    function timestamp(bytes32 data) external returns (uint64) {
        uint64 time = _time();

        _timestamp(data, time);

        return time;
    }

    /// @inheritdoc IEAS
    function getAttestation(bytes32 uid) external view returns (Attestation memory) {
        return _db[uid];
    }

    /// @inheritdoc IEAS
    function isAttestationValid(bytes32 uid) public view returns (bool) {
        return _db[uid].uid != EMPTY_UID;
    }

    /// @inheritdoc IEAS
    function getTimestamp(bytes32 data) external view returns (uint64) {
        return _timestamps[data];
    }

    /// @dev Attests to a specific schema.
    /// @param schemaUID The unique identifier of the schema to attest to.
    /// @param data The arguments of the attestation requests.
    /// @param attester The attesting account.
    /// @param availableValue The total available ETH amount that can be sent to the resolver.
    /// @param last Whether this is the last attestations/revocations set.
    /// @return The UID of the new attestations and the total sent ETH amount.
    function _attest(
        bytes32 schemaUID,
        AttestationRequestData[] memory data,
        address attester,
        uint256 availableValue,
        bool last
    ) private returns (AttestationsResult memory) {
        uint256 length = data.length;

        AttestationsResult memory res;
        res.uids = new bytes32[](length);

        // Ensure that we aren't attempting to attest to a non-existing schema.
        SchemaRecord memory schemaRecord = _schemaRegistry.getSchema(schemaUID);
        if (schemaRecord.uid == EMPTY_UID) {
            revert InvalidSchema();
        }

        Attestation[] memory attestations = new Attestation[](length);
        uint256[] memory values = new uint256[](length);

        for (uint256 i = 0; i < length; i = uncheckedInc(i)) {
            AttestationRequestData memory request = data[i];

            // Ensure that either no expiration time was set or that it was set in the future.
            if (request.expirationTime != NO_EXPIRATION_TIME && request.expirationTime <= _time()) {
                revert InvalidExpirationTime();
            }

            // Ensure that we aren't trying to make a revocable attestation for a non-revocable schema.
            if (!schemaRecord.revocable && request.revocable) {
                revert Irrevocable();
            }

            Attestation memory attestation = Attestation({
                uid: EMPTY_UID,
                schema: schemaUID,
                refUID: request.refUID,
                time: _time(),
                expirationTime: request.expirationTime,
                revocationTime: 0,
                recipient: request.recipient,
                attester: attester,
                revocable: request.revocable,
                data: request.data
            });

            // Look for the first non-existing UID (and use a bump seed/nonce in the rare case of a conflict).
            bytes32 uid;
            uint32 bump = 0;
            while (true) {
                uid = _getUID(attestation, bump);
                if (_db[uid].uid == EMPTY_UID) {
                    break;
                }

                unchecked {
                    ++bump;
                }
            }
            attestation.uid = uid;

            _db[uid] = attestation;

            if (request.refUID != EMPTY_UID) {
                // Ensure that we aren't trying to attest to a non-existing referenced UID.
                if (!isAttestationValid(request.refUID)) {
                    revert NotFound();
                }
            }

            attestations[i] = attestation;
            values[i] = request.value;

            res.uids[i] = uid;

            emit Attested(request.recipient, attester, uid, schemaUID);
        }

        res.usedValue = _resolveAttestations(schemaRecord, attestations, values, false, availableValue, last);

        return res;
    }

    /// @dev Revokes an existing attestation to a specific schema.
    /// @param schemaUID The unique identifier of the schema to attest to.
    /// @param data The arguments of the revocation requests.
    /// @param revoker The revoking account.
    /// @param availableValue The total available ETH amount that can be sent to the resolver.
    /// @param last Whether this is the last attestations/revocations set.
    /// @return Returns the total sent ETH amount.
    function _revoke(
        bytes32 schemaUID,
        RevocationRequestData[] memory data,
        address revoker,
        uint256 availableValue,
        bool last
    ) private returns (uint256) {
        // Ensure that a non-existing schema ID wasn't passed by accident.
        SchemaRecord memory schemaRecord = _schemaRegistry.getSchema(schemaUID);
        if (schemaRecord.uid == EMPTY_UID) {
            revert InvalidSchema();
        }

        uint256 length = data.length;
        Attestation[] memory attestations = new Attestation[](length);
        uint256[] memory values = new uint256[](length);

        for (uint256 i = 0; i < length; i = uncheckedInc(i)) {
            RevocationRequestData memory request = data[i];

            Attestation storage attestation = _db[request.uid];

            // Ensure that we aren't attempting to revoke a non-existing attestation.
            if (attestation.uid == EMPTY_UID) {
                revert NotFound();
            }

            // Ensure that a wrong schema ID wasn't passed by accident.
            if (attestation.schema != schemaUID) {
                revert InvalidSchema();
            }

            // Allow only original attesters to revoke their attestations.
            if (attestation.attester != revoker) {
                revert AccessDenied();
            }

            // Please note that also checking of the schema itself is revocable is unnecessary, since it's not possible to
            // make revocable attestations to an irrevocable schema.
            if (!attestation.revocable) {
                revert Irrevocable();
            }

            // Ensure that we aren't trying to revoke the same attestation twice.
            if (attestation.revocationTime != 0) {
                revert AlreadyRevoked();
            }
            attestation.revocationTime = _time();

            attestations[i] = attestation;
            values[i] = request.value;

            emit Revoked(attestations[i].recipient, revoker, request.uid, schemaUID);
        }

        return _resolveAttestations(schemaRecord, attestations, values, true, availableValue, last);
    }

    /// @dev Calculates a UID for a given attestation.
    /// @param attestation The input attestation.
    /// @param bump A bump value to use in case of a UID conflict.
    /// @return Attestation UID.
    function _getUID(Attestation memory attestation, uint32 bump) private pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                attestation.schema,
                attestation.recipient,
                attestation.attester,
                attestation.time,
                attestation.expirationTime,
                attestation.revocable,
                attestation.refUID,
                attestation.data,
                bump
            )
        );
    }

    /// @dev Refunds remaining ETH amount to the attester.
    /// @param remainingValue The remaining ETH amount that was not sent to the resolver.
    function _refund(uint256 remainingValue) private {
        if (remainingValue > 0) {
            // Using a regular transfer here might revert, for some non-EOA attesters, due to exceeding of the 2300
            // gas limit which is why we're using call instead (via sendValue), which the 2300 gas limit does not
            // apply for.
            payable(msg.sender).sendValue(remainingValue);
        }
    }

    /// @dev Timestamps the specified bytes32 data.
    /// @param data The data to timestamp.
    /// @param time The timestamp.
    function _timestamp(bytes32 data, uint64 time) private {
        if (_timestamps[data] != 0) {
            revert AlreadyTimestamped();
        }

        _timestamps[data] = time;

        emit Timestamped(data, time);
    }
}
