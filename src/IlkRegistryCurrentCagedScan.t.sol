// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

interface CagedScanRegistryLike {
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function class(bytes32 ilk) external view returns (uint256);
    function join(bytes32 ilk) external view returns (address);
}

interface CagedScanJoinLike {
    function live() external view returns (uint256);
}

contract IlkRegistryCurrentCagedScanTest is Test {
    uint256 internal constant SNAPSHOT_BLOCK = 25_694_337;
    address internal constant REGISTRY = 0x5a464C28D19848f44199D003BeF5ecc87d090F87;

    function testEnumerateCurrentPubliclyRemovableRegistryEntries() public {
        vm.createSelectFork("mainnet", SNAPSHOT_BLOCK);
        CagedScanRegistryLike registry = CagedScanRegistryLike(REGISTRY);
        bytes32[] memory ilks = registry.list();
        uint256 publiclyRemovable;

        assertEq(ilks.length, registry.count(), "list/count mismatch");
        console2.log("snapshot block", block.number);
        console2.log("registry count", ilks.length);

        for (uint256 i = 0; i < ilks.length; i++) {
            uint256 cls = registry.class(ilks[i]);
            address join = registry.join(ilks[i]);
            if (join == address(0) || (cls != 1 && cls != 2)) continue;

            try CagedScanJoinLike(join).live() returns (uint256 live) {
                if (live == 0) {
                    publiclyRemovable++;
                    console2.log("publicly removable index", i);
                    console2.logBytes32(ilks[i]);
                    console2.log("join", join);
                    console2.log("class", cls);
                }
            } catch {}
        }

        console2.log("current publicly removable Registry entries", publiclyRemovable);
    }
}
