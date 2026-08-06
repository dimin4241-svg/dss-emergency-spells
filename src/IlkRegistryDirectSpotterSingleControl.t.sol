// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

interface SingleRegistryLike {
    function vat() external view returns (address);
    function join(bytes32) external view returns (address);
    function add(address adapter) external;
}

interface SingleVatLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}

interface SingleSpotterLike {
    function poke(bytes32 ilk) external;
}

interface SingleOmegaLike {
    function refresh() external;
    function poke() external;
}

contract IlkRegistryDirectSpotterSingleControlTest is Test {
    uint256 internal constant SNAPSHOT_BLOCK = 25_694_337;
    bytes32 internal constant LINK_A = "LINK-A";

    address internal constant REGISTRY = 0x5a464C28D19848f44199D003BeF5ecc87d090F87;
    address internal constant MCD_SPOT = 0x65C79fcB50Ca1594B025960e539eD7A9a6D434A3;
    address internal constant OMEGA_POKER = 0xDd538C362dF996727054AC8Fb67ef5394eC9b8b9;
    address internal constant LINK_JOIN = 0xdFccAf8fDbD2F4805C174f856a317765B49E4a50;

    function _spot() internal view returns (uint256 value) {
        address vat = SingleRegistryLike(REGISTRY).vat();
        (,, value,,) = SingleVatLike(vat).ilks(LINK_A);
    }

    function testDirectPublicSpotterPokeMatchesRegistryOmegaLinkSpotResult() public {
        uint256 directFork = vm.createFork("mainnet", SNAPSHOT_BLOCK);
        uint256 registryFork = vm.createFork("mainnet", SNAPSHOT_BLOCK);

        vm.selectFork(directFork);
        uint256 baseline = _spot();
        assertEq(SingleRegistryLike(REGISTRY).join(LINK_A), address(0), "LINK-A unexpectedly registered");
        SingleSpotterLike(MCD_SPOT).poke(LINK_A);
        uint256 directAfter = _spot();

        vm.selectFork(registryFork);
        assertEq(_spot(), baseline, "fork baselines differ");
        assertEq(SingleRegistryLike(REGISTRY).join(LINK_A), address(0), "LINK-A unexpectedly registered");
        SingleRegistryLike(REGISTRY).add(LINK_JOIN);
        SingleOmegaLike(OMEGA_POKER).refresh();
        SingleOmegaLike(OMEGA_POKER).poke();
        uint256 registryAfter = _spot();

        console2.log("LINK-A baseline spot", baseline);
        console2.log("LINK-A direct public Spotter result", directAfter);
        console2.log("LINK-A Registry plus Omega result", registryAfter);
        console2.log("final values equal", directAfter == registryAfter);

        assertTrue(directAfter != baseline, "direct public Spotter poke produced no change");
        assertEq(registryAfter, directAfter, "Registry/Omega produced a distinct Vat.spot result");
    }
}
