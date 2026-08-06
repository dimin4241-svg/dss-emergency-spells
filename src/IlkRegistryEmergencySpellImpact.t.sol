// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {
    IlkRegistryCurrentMassReAddTest,
    CurrentJoinLike,
    CurrentVatLike
} from "./IlkRegistryCurrentMassReAdd.t.sol";

interface EmergencyChainlogLike {
    function getAddress(bytes32 key) external view returns (address);
}

interface EmergencySpellLike {
    function schedule() external;
    function done() external view returns (bool);
}

interface EmergencyOsmMomLike {
    function osms(bytes32 ilk) external view returns (address);
}

interface EmergencyOsmLike {
    function stopped() external view returns (uint256);
    function wards(address who) external view returns (uint256);
}

interface EmergencyClipLike {
    function stopped() external view returns (uint256);
    function wards(address who) external view returns (uint256);
}

contract IlkRegistryEmergencySpellImpactTest is IlkRegistryCurrentMassReAddTest {
    using stdStorage for StdStorage;

    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address internal constant MULTI_OSM_STOP = 0x3021dEdB0bC677F43A23Fcd1dE91A07e5195BaE8;
    address internal constant MULTI_CLIP_BREAKER = 0x828824dBC62Fba126C76E0Abe79AE28E5393C2cb;

    function _chainlogAddress(bytes32 key) internal view returns (address) {
        return EmergencyChainlogLike(CHAINLOG).getAddress(key);
    }

    function _setHat(address spell) internal {
        stdstore.target(_chainlogAddress("MCD_ADM")).sig("hat()").checked_write(spell);
    }

    function _restoreAll() internal returns (uint256 restored) {
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

    function _countPendingRestoredOsms(bool logItems) internal view returns (uint256 pending) {
        EmergencyOsmMomLike osmMom = EmergencyOsmMomLike(_chainlogAddress("OSM_MOM"));
        bytes32[] memory targets = _targets();

        for (uint256 i = 0; i < targets.length; i++) {
            address osm = osmMom.osms(targets[i]);
            if (osm == address(0)) continue;

            try EmergencyOsmLike(osm).wards(address(osmMom)) returns (uint256 ward) {
                if (ward == 0) continue;
            } catch {
                continue;
            }

            try EmergencyOsmLike(osm).stopped() returns (uint256 stopped) {
                if (stopped == 0) {
                    pending++;
                    if (logItems) {
                        console2.log("pending restored OSM ilk");
                        console2.logBytes32(targets[i]);
                        console2.log("OSM", osm);
                    }
                }
            } catch {}
        }
    }

    function _countPendingRestoredClips(bool logItems) internal view returns (uint256 pending) {
        address clipperMom = _chainlogAddress("CLIPPER_MOM");
        bytes32[] memory targets = _targets();

        for (uint256 i = 0; i < targets.length; i++) {
            address clip = registry.xlip(targets[i]);
            if (clip == address(0)) continue;

            try EmergencyClipLike(clip).wards(clipperMom) returns (uint256 ward) {
                if (ward == 0) continue;
            } catch {
                continue;
            }

            try EmergencyClipLike(clip).stopped() returns (uint256 stopped) {
                if (stopped != 3) {
                    pending++;
                    if (logItems) {
                        console2.log("pending restored Clip ilk");
                        console2.logBytes32(targets[i]);
                        console2.log("Clip", clip);
                        console2.log("breaker before re-execution", stopped);
                    }
                }
            } catch {}
        }
    }

    function testPostExecutionReAddReopensDeployedMultiOsmStopCompletion() public {
        vm.createSelectFork("mainnet", SNAPSHOT_BLOCK);
        EmergencySpellLike spell = EmergencySpellLike(MULTI_OSM_STOP);
        _setHat(MULTI_OSM_STOP);

        uint256 firstGasBefore = gasleft();
        spell.schedule();
        uint256 firstGas = firstGasBefore - gasleft();
        assertTrue(spell.done(), "clean emergency OSM stop did not complete");

        uint256 restored = _restoreAll();
        uint256 pending = _countPendingRestoredOsms(true);
        bool doneAfterRestore = spell.done();

        uint256 secondGasBefore = gasleft();
        spell.schedule();
        uint256 secondGas = secondGasBefore - gasleft();

        console2.log("restored legacy ilks", restored);
        console2.log("new pending OSM obligations", pending);
        console2.log("done after restoration", doneAfterRestore);
        console2.log("clean emergency schedule gas", firstGas);
        console2.log("re-execution gas after restoration", secondGas);
        console2.log("block gas limit", block.gaslimit);

        assertEq(restored, 31, "unexpected restored count");
        assertGt(pending, 0, "restoration created no new emergency OSM obligations");
        assertFalse(doneAfterRestore, "restoration did not reopen emergency completion");
        assertTrue(spell.done(), "second emergency execution did not close restored obligations");
        assertLt(secondGas, block.gaslimit, "second emergency execution exceeds block gas limit");
    }

    function testPostExecutionReAddReopensDeployedMultiClipBreakerCompletion() public {
        vm.createSelectFork("mainnet", SNAPSHOT_BLOCK);
        EmergencySpellLike spell = EmergencySpellLike(MULTI_CLIP_BREAKER);
        _setHat(MULTI_CLIP_BREAKER);

        uint256 firstGasBefore = gasleft();
        spell.schedule();
        uint256 firstGas = firstGasBefore - gasleft();
        assertTrue(spell.done(), "clean emergency Clip breaker did not complete");

        uint256 restored = _restoreAll();
        uint256 pending = _countPendingRestoredClips(true);
        bool doneAfterRestore = spell.done();

        uint256 secondGasBefore = gasleft();
        spell.schedule();
        uint256 secondGas = secondGasBefore - gasleft();

        console2.log("restored legacy ilks", restored);
        console2.log("new pending Clip obligations", pending);
        console2.log("done after restoration", doneAfterRestore);
        console2.log("clean emergency schedule gas", firstGas);
        console2.log("re-execution gas after restoration", secondGas);
        console2.log("block gas limit", block.gaslimit);

        assertEq(restored, 31, "unexpected restored count");
        assertGt(pending, 0, "restoration created no new emergency Clip obligations");
        assertFalse(doneAfterRestore, "restoration did not reopen emergency completion");
        assertTrue(spell.done(), "second emergency execution did not close restored obligations");
        assertLt(secondGas, block.gaslimit, "second emergency execution exceeds block gas limit");
    }
}
