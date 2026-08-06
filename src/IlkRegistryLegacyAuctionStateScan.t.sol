// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {console2} from "forge-std/console2.sol";
import {
    IlkRegistryCurrentMassReAddTest,
    CurrentJoinLike,
    CurrentVatLike
} from "./IlkRegistryCurrentMassReAdd.t.sol";

interface AuctionScanRegistryLike {
    function class(bytes32 ilk) external view returns (uint256);
    function xlip(bytes32 ilk) external view returns (address);
}

interface AuctionScanClipLike {
    function count() external view returns (uint256);
    function stopped() external view returns (uint256);
}

interface AuctionScanVatLike is CurrentVatLike {
    function gem(bytes32 ilk, address usr) external view returns (uint256);
    function dai(address usr) external view returns (uint256);
}

contract IlkRegistryLegacyAuctionStateScanTest is IlkRegistryCurrentMassReAddTest {
    function _restore() internal {
        bytes32[] memory targets = _targets();
        address[] memory adapters = _adapters();
        CurrentVatLike vat = CurrentVatLike(registry.vat());
        for (uint256 i = 0; i < targets.length; i++) {
            assertEq(CurrentJoinLike(adapters[i]).live(), 1, "legacy Join not live");
            assertEq(vat.wards(adapters[i]), 1, "legacy Join not authorized");
            registry.add(adapters[i]);
        }
    }

    function testScanRestoredLegacyClippersForActiveAuctionsAndBalances() public {
        vm.createSelectFork("mainnet", SNAPSHOT_BLOCK);
        _restore();

        AuctionScanRegistryLike reg = AuctionScanRegistryLike(REGISTRY);
        AuctionScanVatLike vat = AuctionScanVatLike(registry.vat());
        bytes32[] memory targets = _targets();
        uint256 clipperEntries;
        uint256 withActiveAuctions;
        uint256 withInternalGem;
        uint256 totalActiveAuctions;

        for (uint256 i = 0; i < targets.length; i++) {
            if (reg.class(targets[i]) != 1) continue;
            address clip = reg.xlip(targets[i]);
            if (clip == address(0)) continue;
            clipperEntries++;

            uint256 active = AuctionScanClipLike(clip).count();
            uint256 internalGem = vat.gem(targets[i], clip);
            uint256 internalDai = vat.dai(clip);
            uint256 stopped = AuctionScanClipLike(clip).stopped();

            if (active != 0 || internalGem != 0 || internalDai != 0) {
                console2.log("legacy Clipper with residual state");
                console2.logBytes32(targets[i]);
                console2.log("clip", clip);
                console2.log("active auctions", active);
                console2.log("Vat.gem at clip", internalGem);
                console2.log("Vat.dai at clip", internalDai);
                console2.log("breaker level", stopped);
            }

            if (active != 0) {
                withActiveAuctions++;
                totalActiveAuctions += active;
            }
            if (internalGem != 0) withInternalGem++;
        }

        console2.log("restored Clipper entries", clipperEntries);
        console2.log("legacy Clippers with active auctions", withActiveAuctions);
        console2.log("total active legacy auctions", totalActiveAuctions);
        console2.log("legacy Clippers with Vat.gem balance", withInternalGem);
    }
}
