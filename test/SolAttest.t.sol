// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SolAttest.sol";

contract SolAttestTest is Test {
    SolAttest private solAttest;
    address private attester = address(1);
    address private recipient = address(2);
    string private testData = "This is an attestation!!";

    function setUp() public {
        solAttest = new SolAttest();
    }

    function testAttestSuccess() public {
        vm.startPrank(attester);
        uint256 uid = solAttest.attest(recipient, true, testData);
        assertEq(uid, 1, "UID should be 1 for the first attestation");

        SolAttest.Attestation memory attestation = solAttest.getAttestation(uid);
        assertEq(attestation.attester, attester, "Attester address does not match");
        assertEq(attestation.recipient, recipient, "Recipient address does not match");
        assertEq(attestation.data, testData, "Attestation data does not match");
        assertTrue(attestation.revocable, "Attestation should be revocable");
        vm.stopPrank();
    }

    function testRevokeSuccess() public {
        vm.startPrank(attester);
        uint256 uid = solAttest.attest(recipient, true, testData);
        solAttest.revoke(uid);

        SolAttest.Attestation memory attestation = solAttest.getAttestation(uid);
        assertTrue(attestation.revocationTime != 0, "Revocation time was not set");
        vm.stopPrank();
    }

    // Additional tests for error handling
    // Use vm.expectRevert(ExpectedError.selector) to check for specific errors
    // Example:
    // function testNotFound() public {
    //     vm.expectRevert(NotFound.selector);
    //     solAttest.getAttestation(999);
    // }
    // Implement similar tests for AccessDenied, AlreadyRevoked, and Irrevocable errors
}
