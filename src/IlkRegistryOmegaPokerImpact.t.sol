// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {IlkRegistryCurrentMassReAddTest, CurrentJoinLike, CurrentVatLike} from "./IlkRegistryCurrentMassReAdd.t.sol";
import {console2} from "forge-std/console2.sol";

interface OmegaPokerLike {
    function registry() external view returns (address);
    function spot() external view returns (address);
    function ilkCount() external view returns (uint256);
    function osmCount() external view returns (uint256);
    function ilks(uint256) external view returns (bytes32);
    function osms(uint256) external view returns (address);
    function refresh() external;
    function poke() external;
}

contract IlkRegistryOmegaPokerImpactTest is IlkRegistryCurrentMassReAddTest {
    address internal constant OMEGA_POKER = 0xDd538C362dF996727054AC8Fb67ef5394eC9b8b9;

    struct OmegaMetrics {
        uint256 refreshGas;
        uint256 pokeGas;
        uint256 ilkCount;
        uint256 osmCount;
        uint256 legacyCached;
        uint256 spotsChanged;
        uint256 spotsNonzero;
    }

    function _restoreLegacyIlks() internal returns (uint256 restored) {
        bytes32[] memory targets = _targets();
        address[] memory adapters = _adapters();
        CurrentVatLike vat = CurrentVatLike(registry.vat());

        for (uint256 i = 0; i < targets.length; i++) {
            assertEq(registry.join(targets[i]), address(0), "legacy target unexpectedly present");
            assertEq(CurrentJoinLike(adapters[i]).live(), 1, "legacy adapter is not live");
            assertEq(vat.wards(adapters[i]), 1, "legacy adapter is not a Vat ward");
            registry.add(adapters[i]);
            restored++;
        }
    }

    function _containsOmegaIlk(OmegaPokerLike omega, bytes32 needle) internal view returns (bool) {
        uint256 n = omega.ilkCount();
        for (uint256 i = 0; i < n; i++) {
            if (omega.ilks(i) == needle) return true;
        }
        return false;
    }

    function _refreshMetrics(OmegaPokerLike omega) internal returns (OmegaMetrics memory m) {
        uint256 beforeGas = gasleft();
        omega.refresh();
        m.refreshGas = beforeGas - gasleft();
        m.ilkCount = omega.ilkCount();
        m.osmCount = omega.osmCount();
    }

    function _pokeOnly(OmegaPokerLike omega) internal returns (uint256 pokeGas) {
        uint256 beforeGas = gasleft();
        omega.poke();
        pokeGas = beforeGas - gasleft();
    }

    function _snapshotLegacyState(OmegaPokerLike omega)
        internal
        view
        returns (bytes32[] memory targets, uint256[] memory spotsBefore, uint256 legacyCached)
    {
        targets = _targets();
        spotsBefore = new uint256[](targets.length);
        CurrentVatLike vat = CurrentVatLike(registry.vat());

        for (uint256 i = 0; i < targets.length; i++) {
            if (_containsOmegaIlk(omega, targets[i])) legacyCached++;
            (,, spotsBefore[i],,) = vat.ilks(targets[i]);
        }
    }

    function _compareLegacySpots(bytes32[] memory targets, uint256[] memory spotsBefore)
        internal
        view
        returns (uint256 changed, uint256 nonzero)
    {
        CurrentVatLike vat = CurrentVatLike(registry.vat());
        for (uint256 i = 0; i < targets.length; i++) {
            (,, uint256 spotAfter,,) = vat.ilks(targets[i]);
            if (spotAfter != spotsBefore[i]) {
                changed++;
                console2.log("Omega changed legacy ilk:");
                console2.logBytes32(targets[i]);
                console2.log("spot before", spotsBefore[i]);
                console2.log("spot after", spotAfter);
            }
            if (spotAfter != 0) nonzero++;
        }
    }

    function _cleanMetrics(OmegaPokerLike omega) internal returns (OmegaMetrics memory m) {
        m = _refreshMetrics(omega);
        m.pokeGas = _pokeOnly(omega);
    }

    function _attackedMetrics(OmegaPokerLike omega)
        internal
        returns (OmegaMetrics memory m, uint256 initialRegistryCount, uint256 restored, uint256 attackedRegistryCount)
    {
        initialRegistryCount = registry.count();
        restored = _restoreLegacyIlks();
        attackedRegistryCount = registry.count();

        m = _refreshMetrics(omega);
        (bytes32[] memory targets, uint256[] memory spotsBefore, uint256 legacyCached) =
            _snapshotLegacyState(omega);
        m.legacyCached = legacyCached;
        m.pokeGas = _pokeOnly(omega);
        (m.spotsChanged, m.spotsNonzero) = _compareLegacySpots(targets, spotsBefore);
    }

    function _logMetrics(
        OmegaMetrics memory clean,
        OmegaMetrics memory attacked,
        uint256 initialRegistryCount,
        uint256 restored,
        uint256 attackedRegistryCount
    ) internal view {
        console2.log("fork block", block.number);
        console2.log("initial registry count", initialRegistryCount);
        console2.log("restored legacy ilks", restored);
        console2.log("attacked registry count", attackedRegistryCount);
        console2.log("clean Omega ilk count", clean.ilkCount);
        console2.log("attacked Omega ilk count", attacked.ilkCount);
        console2.log("clean Omega OSM count", clean.osmCount);
        console2.log("attacked Omega OSM count", attacked.osmCount);
        console2.log("legacy ilks cached by Omega", attacked.legacyCached);
        console2.log("clean refresh gas", clean.refreshGas);
        console2.log("attack refresh gas", attacked.refreshGas);
        console2.log("clean poke gas", clean.pokeGas);
        console2.log("attack poke gas", attacked.pokeGas);
        console2.log("legacy Vat spots changed by poke", attacked.spotsChanged);
        console2.log("legacy Vat spots nonzero after poke", attacked.spotsNonzero);
        console2.log("block gas limit", block.gaslimit);
    }

    function testMassReAddChangesDeployedOmegaPokerExecution() public {
        uint256 cleanFork = vm.createFork("mainnet", SNAPSHOT_BLOCK);
        uint256 attackFork = vm.createFork("mainnet", SNAPSHOT_BLOCK);
        OmegaPokerLike omega = OmegaPokerLike(OMEGA_POKER);

        vm.selectFork(cleanFork);
        assertEq(omega.registry(), REGISTRY, "OmegaPoker does not use production Registry");
        OmegaMetrics memory clean = _cleanMetrics(omega);

        vm.selectFork(attackFork);
        (
            OmegaMetrics memory attacked,
            uint256 initialRegistryCount,
            uint256 restored,
            uint256 attackedRegistryCount
        ) = _attackedMetrics(omega);

        _logMetrics(clean, attacked, initialRegistryCount, restored, attackedRegistryCount);

        assertEq(initialRegistryCount, 35, "unexpected pinned Registry baseline");
        assertEq(restored, 31, "unexpected number of restorable legacy ilks");
        assertEq(attackedRegistryCount, 66, "Registry restoration mismatch");
        assertGt(attacked.ilkCount, clean.ilkCount, "OmegaPoker cache did not expand");
        assertGt(attacked.osmCount, clean.osmCount, "OmegaPoker OSM set did not expand");
        assertGt(attacked.legacyCached, 0, "OmegaPoker cached no restored legacy ilks");
        assertGt(attacked.pokeGas, clean.pokeGas, "OmegaPoker poke execution did not expand");
        assertGt(attacked.spotsChanged, 0, "OmegaPoker did not propagate restored ilks into Vat spot updates");
        assertLt(attacked.refreshGas, block.gaslimit, "attacked refresh does not fit in a block");
        assertLt(attacked.pokeGas, block.gaslimit, "attacked poke does not fit in a block");
    }
}
