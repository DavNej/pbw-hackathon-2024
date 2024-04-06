// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {EMPTY_UID} from "./Common.sol";

struct SchemaRecord {
    bytes32 uid; // The unique identifier of the schema.
    bool revocable; // Whether the schema allows revocations explicitly.
    string schema; // Custom specification of the schema (e.g., an ABI).
}

/// @title SchemaRegistry
/// @notice The global schema registry.

contract SchemaRegistry {
    error AlreadyExists();

    event Registered(bytes32 indexed uid, address indexed registerer, SchemaRecord schema);

    /// @notice A struct representing a record for a submitted schema.

    // The global mapping between schema records and their IDs.
    mapping(bytes32 uid => SchemaRecord schemaRecord) private _registry;

    constructor() {}

    /// @notice Submits and reserves a new schema
    /// @param schema The schema data schema.
    /// @param revocable Whether the schema allows revocations explicitly.
    /// @return The UID of the new schema.
    function register(string calldata schema, bool revocable) external returns (bytes32) {
        SchemaRecord memory schemaRecord = SchemaRecord({uid: EMPTY_UID, schema: schema, revocable: revocable});

        bytes32 uid = _getUID(schemaRecord);
        if (_registry[uid].uid != EMPTY_UID) {
            revert AlreadyExists();
        }

        schemaRecord.uid = uid;
        _registry[uid] = schemaRecord;

        emit Registered(uid, msg.sender, schemaRecord);

        return uid;
    }

    /// @notice Returns an existing schema by UID
    /// @param uid The UID of the schema to retrieve.
    /// @return The schema data members.
    function getSchema(bytes32 uid) external view returns (SchemaRecord memory) {
        return _registry[uid];
    }

    /// @dev Calculates a UID for a given schema.
    /// @param schemaRecord The input schema.
    /// @return schema UID.
    function _getUID(SchemaRecord memory schemaRecord) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(schemaRecord.schema, schemaRecord.revocable));
    }
}
