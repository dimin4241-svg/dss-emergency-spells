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

    function _restoreLegacyIlks() internal returns (uint256 restored) {
        bytes32[] memory targets = _targets();
        address[] memory adapters = _adapters();
        CurrentVatLike vat = CurrentVatLike(registry.vat());

        for (uint256 i = 0; i < targets.length; i++) {
            if (registry.join(targets[i]) != address(0)) continue;
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

    function testMassReAddChangesDeployedOmegaPokerExecution() public {
        uint256 cleanFork = vm.createFork("mainnet");
        uint256 attackFork = vm.createFork("mainnet");
        OmegaPokerLike omega = OmegaPokerLike(OMEGA_POKER);

        vm.selectFork(cleanFork);
        assertEq(omega.registry(), REGISTRY, "OmegaPoker does not use production Registry");
        uint256 cleanRefreshGasBefore = gasleft();
        omega.refresh();
        uint256 cleanRefreshGas = cleanRefreshGasBefore - gasleft();
        uint256 cleanIlkCount = omega.ilkCount();
        uint256 cleanOsmCount = omega.osmCount();
        uint256 cleanPokeGasBefore = gasleft();
        omega.poke();
        uint256 cleanPokeGas = cleanPokeGasBefore - gasleft();

        vm.selectFork(attackFork);
        uint256 initialRegistryCount = registry.count();
        uint256 restored = _restoreLegacyIlks();
        uint256 attackedRegistryCount = registry.count();

        uint256 attackRefreshGasBefore = gasleft();
        omega.refresh();
        uint256 attackRefreshGas = attackRefreshGasBefore - gasleft();
        uint256 attackIlkCount = omega.ilkCount();
        uint256 attackOsmCount = omega.osmCount();

        bytes32[] memory targets = _targets();
        uint256 legacyIlksCached;
        uint256[] memory spotBefore = new uint256[](targets.length);
        CurrentVatLike vat = CurrentVatLike(registry.vat());
        for (uint256 i = 0; i < targets.length; i++) {
            if (_containsOmegaIlk(omega, targets[i])) legacyIlksCached++;
            (,, spotBefore[i],,) = vat.ilks(targets[i]);
        }

        uint256 attackPokeGasBefore = gasleft();
        omega.poke();
        uint256 attackPokeGas = attackPokeGasBefore - gasleft();

        uint256 legacyVatSpotsChanged;
        uint256 legacyVatSpotsNonzero;
        for (uint256 i = 0; i < targets.length; i++) {
            (,, uint256 spotAfter,,) = vat.ilks(targets[i]);
            if (spotAfter != spotBefore[i]) legacyVatSpotsChanged++;
            if (spotAfter != 0) legacyVatSpotsNonzero++;
        }

        console2.log("fork block", block.number);
        console2.log("initial registry count", initialRegistryCount);
        console2.log("restored legacy ilks", restored);
        console2.log("attacked registry count", attackedRegistryCount);
        console2.log("clean Omega ilk count", cleanIlkCount);
        console2.log("attacked Omega ilk count", attackIlkCount);
        console2.log("clean Omega OSM count", cleanOsmCount);
        console2.log("attacked Omega OSM count", attackOsmCount);
        console2.log("legacy ilks cached by Omega", legacyIlksCached);
        console2.log("clean refresh gas", cleanRefreshGas);
        console2.log("attack refresh gas", attackRefreshGas);
        console2.log("clean poke gas", cleanPokeGas);
        console2.log("attack poke gas", attackPokeGas);
        console2.log("legacy Vat spots changed by poke", legacyVatSpotsChanged);
        console2.log("legacy Vat spots nonzero after poke", legacyVatSpotsNonzero);
        console2.log("block gas limit", block.gaslimit);

        assertEq(restored, 31, "unexpected number of currently restorable legacy ilks");
        assertEq(attackedRegistryCount, initialRegistryCount + restored, "Registry restoration mismatch");
        assertGt(attackIlkCount, cleanIlkCount, "OmegaPoker cache did not expand");
        assertGt(legacyIlksCached, 0, "OmegaPoker cached no restored legacy ilks");
        assertGt(attackPokeGas, cleanPokeGas, "OmegaPoker poke execution did not expand");
        assertLt(attackRefreshGas, block.gaslimit, "attacked refresh does not fit in a block");
        assertLt(attackPokeGas, block.gaslimit, "attacked poke does not fit in a block");
    }
}
