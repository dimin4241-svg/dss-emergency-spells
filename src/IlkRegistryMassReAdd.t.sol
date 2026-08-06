// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

interface RegistryMassLike {
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function join(bytes32) external view returns (address);
    function add(address) external;
}

interface JoinMassLike {
    function live() external view returns (uint256);
}

interface SpellMassLike {
    function cast() external;
    function done() external view returns (bool);
}

contract IlkRegistryMassReAddTest is Test {
    uint256 internal constant PRE_CAST_BLOCK = 23_118_263;
    address internal constant REGISTRY = 0x5a464C28D19848f44199D003BeF5ecc87d090F87;
    address internal constant CLEANUP_SPELL = 0x26009aFf7fE39bF7611d66E0D38CAc43b3A93CD5;

    RegistryMassLike internal constant registry = RegistryMassLike(REGISTRY);
    SpellMassLike internal constant spell = SpellMassLike(CLEANUP_SPELL);

    function _targets() internal pure returns (bytes32[] memory t) {
        t = new bytes32[](42);
        t[0] = "LSE-MKR-A";
        t[1] = "AAVE-A";
        t[2] = "BAL-A";
        t[3] = "BAT-A";
        t[4] = "COMP-A";
        t[5] = "CRVV1ETHSTETH-A";
        t[6] = "GNO-A";
        t[7] = "GUSD-A";
        t[8] = "KNC-A";
        t[9] = "LINK-A";
        t[10] = "LRC-A";
        t[11] = "MANA-A";
        t[12] = "MATIC-A";
        t[13] = "PAXUSD-A";
        t[14] = "RENBTC-A";
        t[15] = "RETH-A";
        t[16] = "RWA003-A";
        t[17] = "RWA006-A";
        t[18] = "RWA007-A";
        t[19] = "RWA008-A";
        t[20] = "RWA010-A";
        t[21] = "RWA011-A";
        t[22] = "RWA012-A";
        t[23] = "RWA013-A";
        t[24] = "RWA014-A";
        t[25] = "RWA015-A";
        t[26] = "TUSD-A";
        t[27] = "UNI-A";
        t[28] = "UNIV2AAVEETH-A";
        t[29] = "UNIV2DAIETH-A";
        t[30] = "UNIV2DAIUSDT-A";
        t[31] = "UNIV2ETHUSDT-A";
        t[32] = "UNIV2LINKETH-A";
        t[33] = "UNIV2UNIETH-A";
        t[34] = "UNIV2USDCETH-A";
        t[35] = "UNIV2WBTCDAI-A";
        t[36] = "UNIV2WBTCETH-A";
        t[37] = "USDC-A";
        t[38] = "USDC-B";
        t[39] = "USDT-A";
        t[40] = "YFI-A";
        t[41] = "ZRX-A";
    }

    function _contains(bytes32 needle) internal view returns (bool) {
        bytes32[] memory values = registry.list();
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] == needle) return true;
        }
        return false;
    }

    function testAttackerMassReAddsGovernanceRemovedIlks() public {
        vm.createSelectFork("mainnet", PRE_CAST_BLOCK);

        bytes32[] memory targets = _targets();
        address[] memory oldJoins = new address[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            oldJoins[i] = registry.join(targets[i]);
        }

        uint256 initialCount = registry.count();
        assertEq(initialCount, 72, "unexpected historical registry count");

        spell.cast();
        assertTrue(spell.done(), "real governance spell did not finish");
        uint256 cleanedCount = registry.count();
        assertEq(cleanedCount, 30, "real spell must remove exactly 42 entries");

        uint256 readded;
        uint256 liveReadded;
        for (uint256 i = 0; i < targets.length; i++) {
            address adapter = oldJoins[i];
            if (adapter == address(0)) continue;

            (bool ok,) = REGISTRY.call(abi.encodeWithSignature("add(address)", adapter));
            if (!ok) continue;

            readded++;
            if (JoinMassLike(adapter).live() == 1) liveReadded++;

            console2.log("re-added ilk:");
            console2.logBytes32(targets[i]);
            console2.log("adapter", adapter);
            console2.log("adapter live", JoinMassLike(adapter).live());

            assertEq(registry.join(targets[i]), adapter, "registry did not restore the old adapter");
            assertTrue(_contains(targets[i]), "re-added target is not enumerable");
        }

        console2.log("governance removals reversed", readded);
        console2.log("re-added adapters still live", liveReadded);
        console2.log("cleaned count", cleanedCount);
        console2.log("post-attack count", registry.count());

        assertEq(readded, 31, "unexpected number of governance removals reversed");
        assertEq(registry.count(), cleanedCount + readded, "every successful add must restore one voted-out entry");
        assertEq(liveReadded, readded, "unexpectedly re-added a caged adapter");
    }
}
