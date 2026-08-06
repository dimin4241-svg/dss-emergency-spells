// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {IlkRegistryOmegaPokerImpactTest, OmegaPokerLike} from "./IlkRegistryOmegaPokerImpact.t.sol";
import {CurrentVatLike} from "./IlkRegistryCurrentMassReAdd.t.sol";
import {console2} from "forge-std/console2.sol";

interface DirectSpotterLike {
    function poke(bytes32 ilk) external;
}

contract IlkRegistryDirectSpotterControlTest is IlkRegistryOmegaPokerImpactTest {
    address internal constant MCD_SPOT = 0x65C79fcB50Ca1594B025960e539eD7A9a6D434A3;

    function _snapshotSpots(bytes32[] memory targets) internal view returns (uint256[] memory spots) {
        CurrentVatLike vat = CurrentVatLike(registry.vat());
        spots = new uint256[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            (,, spots[i],,) = vat.ilks(targets[i]);
        }
    }

    function _directPoke(bytes32[] memory targets) internal {
        for (uint256 i = 0; i < targets.length; i++) {
            DirectSpotterLike(MCD_SPOT).poke(targets[i]);
        }
    }

    function _restoreAndOmegaPoke() internal {
        _restoreLegacyIlks();
        OmegaPokerLike omega = OmegaPokerLike(OMEGA_POKER);
        omega.refresh();
        omega.poke();
    }

    function testDirectSpotterPokeProducesSameVatSpotStateWithoutRegistryReAdd() public {
        uint256 directFork = vm.createFork("mainnet", SNAPSHOT_BLOCK);
        uint256 registryFork = vm.createFork("mainnet", SNAPSHOT_BLOCK);
        bytes32[] memory targets = _targets();

        vm.selectFork(directFork);
        uint256[] memory baseline = _snapshotSpots(targets);
        _directPoke(targets);
        uint256[] memory directAfter = _snapshotSpots(targets);

        vm.selectFork(registryFork);
        _restoreAndOmegaPoke();
        uint256[] memory registryAfter = _snapshotSpots(targets);

        uint256 directChanges;
        uint256 registryChanges;
        uint256 differingFinalValues;
        for (uint256 i = 0; i < targets.length; i++) {
            if (directAfter[i] != baseline[i]) directChanges++;
            if (registryAfter[i] != baseline[i]) registryChanges++;
            if (directAfter[i] != registryAfter[i]) {
                differingFinalValues++;
                console2.log("different final Vat.spot");
                console2.logBytes32(targets[i]);
                console2.log("direct", directAfter[i]);
                console2.log("registry", registryAfter[i]);
            }
        }

        console2.log("direct public Spotter changes", directChanges);
        console2.log("Registry plus Omega changes", registryChanges);
        console2.log("different final values", differingFinalValues);
        console2.log("Registry count on direct fork", uint256(35));
        console2.log("Registry count on attacked fork", registry.count());

        assertEq(directChanges, 15, "unexpected direct Spotter delta count");
        assertEq(registryChanges, 15, "unexpected Registry/Omega delta count");
        assertEq(differingFinalValues, 0, "Registry path produced distinct Vat.spot state");
        assertEq(registry.count(), 66, "Registry attack did not restore records");
    }
}
