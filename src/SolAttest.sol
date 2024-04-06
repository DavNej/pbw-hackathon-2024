// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

error AccessDenied();
error NotFound();
error AlreadyRevoked();
error Irrevocable();

/// @title SolAttest
/// @notice The Solana Attestations protocol.
contract SolAttest {
    uint256 constant EMPTY_UID = 0;
    uint64 constant NO_EXPIRATION_TIME = 0;

    /// @notice Emitted when an attestation has been made.
    /// @param recipient The recipient of the attestation.
    /// @param attester The attesting account.
    /// @param uid The UID the revoked attestation.

    event Attested(address indexed attester, address indexed recipient, uint256 uid);

    /// @notice Emitted when an attestation has been revoked.
    /// @param recipient The recipient of the attestation.
    /// @param attester The attesting account.
    /// @param uid The UID the revoked attestation.
    event Revoked(address indexed recipient, address indexed attester, uint256 uid);

    struct Attestation {
        uint256 uid; // A unique identifier of the attestation.
        uint256 time; // The time when the attestation was created (Unix timestamp).
        uint256 revocationTime; // The time when the attestation was revoked (Unix timestamp).
        address recipient; // The recipient of the attestation.
        address attester; // The attester/sender of the attestation.
        bool revocable; // Whether the attestation is revocable.
        string data; // Custom attestation data.
    }

    // The global mapping between attestations and their UIDs.
    uint256 private lastUid = 0;

    mapping(uint256 uid => Attestation attestation) private _db;

    /// @dev Creates a new SolAttest instance.
    constructor() {}

    /// @notice Attests to a specific schema.
    /// @param recipient The recipient of the attestation.
    /// @param revocable Whether the attestation is revocable.
    /// @param data The custom attestation data.
    /// @return The UID of the new attestation.
    function attest(address recipient, bool revocable, string calldata data) external returns (uint256) {
        uint256 _uid = lastUid++;

        Attestation memory _attestation;

        _attestation.uid = _uid;
        _attestation.attester = msg.sender;
        _attestation.recipient = recipient;
        _attestation.data = data;
        _attestation.time = block.timestamp;
        _attestation.revocable = revocable;

        _db[_uid] = _attestation;

        emit Attested(msg.sender, recipient, _uid);

        return _uid;
    }

    function revoke(uint256 uid) external {
        Attestation storage attestation = _db[uid];

        if (attestation.uid == 0) {
            revert NotFound();
        }

        if (attestation.attester != msg.sender) {
            revert AccessDenied();
        }

        if (attestation.revocationTime != 0) {
            revert AlreadyRevoked();
        }

        if (!attestation.revocable) {
            revert Irrevocable();
        }

        attestation.revocationTime = block.timestamp;
    }

    /// @notice Returns an existing attestation by UID.
    /// @param uid The UID of the attestation to retrieve.
    /// @return The attestation data members.
    function getAttestation(uint256 uid) external view returns (Attestation memory) {
        if (uid > lastUid || uid == 0) {
            revert NotFound();
        }
        return _db[uid];
    }
}
