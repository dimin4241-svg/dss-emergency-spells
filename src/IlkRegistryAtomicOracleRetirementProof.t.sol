// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {console2} from "forge-std/console2.sol";
import {AtomicSpellLike} from "./IlkRegistryAtomicGovernanceReversal.t.sol";
import {
    IlkRegistryChainlogRetirementBypassTest,
    RetirementOmegaLike
} from "./IlkRegistryChainlogRetirementBypass.t.sol";

contract AtomicRetirementExecution {
    function execute(address spell, address registry, address[] calldata adapters, address omega)
        external
        returns (uint256 restored)
    {
        AtomicSpellLike(spell).cast();
        for (uint256 i = 0; i < adapters.length; i++) {
            (bool ok,) = registry.call(abi.encodeWithSignature("add(address)", adapters[i]));
            if (ok) restored++;
        }
        RetirementOmegaLike(omega).refresh();
        RetirementOmegaLike(omega).poke();
    }
}

contract IlkRegistryAtomicOracleRetirementProofTest is IlkRegistryChainlogRetirementBypassTest {
    function testOneExternalCallReactivatesRetiredOraclePathIntoVat() public {
        vm.createSelectFork("mainnet", PRE_CAST_BLOCK);

        address[] memory adapters = _captureAdapters();
        bytes32[] memory selected = _selectedIlks();
        uint256[] memory spotsBefore = _captureSpots(selected);

        AtomicRetirementExecution proof = new AtomicRetirementExecution();
        uint256 gasBefore = gasleft();
        uint256 restored = proof.execute(CLEANUP_SPELL, REGISTRY, adapters, OMEGA_POKER);
        uint256 gasUsed = gasBefore - gasleft();

        uint256 retiredKeys = _countRetiredChainlogKeys();
        uint256 recached = _countSelectedInOmega(true);
        uint256 spotChanges = _countSpotChanges(selected, spotsBefore);

        console2.log("approved spell done", AtomicSpellLike(CLEANUP_SPELL).done());
        console2.log("Chainlog keys still retired", retiredKeys);
        console2.log("Registry ilks restored in same call", restored);
        console2.log("retired ilks recached in same call", recached);
        console2.log("retired Vat.spot values changed in same call", spotChanges);
        console2.log("final Registry count", retirementRegistry.count());
        console2.log("end-to-end call gas used", gasUsed);
        console2.log("block gas limit", block.gaslimit);

        assertTrue(AtomicSpellLike(CLEANUP_SPELL).done(), "approved spell did not finish");
        assertEq(retiredKeys, 8, "selected Chainlog keys were not retired");
        assertEq(restored, 31, "unexpected restored Registry count");
        assertEq(retirementRegistry.count(), 61, "unexpected final Registry count");
        assertGt(recached, 0, "no retired oracle path was recached");
        assertGt(spotChanges, 0, "no retired oracle path reached Vat.spot");
        assertLt(gasUsed, block.gaslimit, "end-to-end call exceeds block gas limit");
    }
}
