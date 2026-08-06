// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {console2} from "forge-std/console2.sol";
import {
    IlkRegistryEmergencySpellImpactTest,
    EmergencySpellLike
} from "./IlkRegistryEmergencySpellImpact.t.sol";

contract IlkRegistryEmergencyReexecutionGriefTest is IlkRegistryEmergencySpellImpactTest {
    function _stagedReexecution(address spellAddress)
        internal
        returns (uint256 additions, uint256 forcedCycles, uint256 totalResponseGas, uint256 maxResponseGas)
    {
        EmergencySpellLike spell = EmergencySpellLike(spellAddress);
        _setHat(spellAddress);
        spell.schedule();
        assertTrue(spell.done(), "initial emergency execution did not complete");

        bytes32[] memory targets = _targets();
        address[] memory adapters = _adapters();

        for (uint256 i = 0; i < adapters.length; i++) {
            registry.add(adapters[i]);
            additions++;

            if (spell.done()) continue;

            forcedCycles++;
            console2.log("forced emergency re-execution for ilk");
            console2.logBytes32(targets[i]);

            uint256 gasBefore = gasleft();
            spell.schedule();
            uint256 responseGas = gasBefore - gasleft();
            totalResponseGas += responseGas;
            if (responseGas > maxResponseGas) maxResponseGas = responseGas;

            assertTrue(spell.done(), "emergency response did not restore completion");
        }
    }

    function testStagedReAddForcesRepeatedMultiOsmStopExecutions() public {
        vm.createSelectFork("mainnet", SNAPSHOT_BLOCK);
        (
            uint256 additions,
            uint256 forcedCycles,
            uint256 totalResponseGas,
            uint256 maxResponseGas
        ) = _stagedReexecution(MULTI_OSM_STOP);

        console2.log("staged Registry additions", additions);
        console2.log("forced OSM emergency re-executions", forcedCycles);
        console2.log("total OSM response gas", totalResponseGas);
        console2.log("maximum single OSM response gas", maxResponseGas);

        assertEq(additions, 31, "unexpected staged addition count");
        assertEq(forcedCycles, 25, "unexpected number of forced OSM response cycles");
    }

    function testStagedReAddForcesRepeatedMultiClipBreakerExecutions() public {
        vm.createSelectFork("mainnet", SNAPSHOT_BLOCK);
        (
            uint256 additions,
            uint256 forcedCycles,
            uint256 totalResponseGas,
            uint256 maxResponseGas
        ) = _stagedReexecution(MULTI_CLIP_BREAKER);

        console2.log("staged Registry additions", additions);
        console2.log("forced Clip emergency re-executions", forcedCycles);
        console2.log("total Clip response gas", totalResponseGas);
        console2.log("maximum single Clip response gas", maxResponseGas);

        assertEq(additions, 31, "unexpected staged addition count");
        assertEq(forcedCycles, 30, "unexpected number of forced Clip response cycles");
    }
}
