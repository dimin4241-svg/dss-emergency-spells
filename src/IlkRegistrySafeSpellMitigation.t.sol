// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

interface SafeRegistryLike {
    function vat() external view returns (address);
    function spot() external view returns (address);
    function join(bytes32 ilk) external view returns (address);
    function add(address adapter) external;
}

interface SafeSpotterLike {
    function wards(address usr) external view returns (uint256);
    function ilks(bytes32 ilk) external view returns (address pip, uint256 mat);
    function file(bytes32 ilk, bytes32 what, address data) external;
}

interface SafeJoinLike {
    function live() external view returns (uint256);
    function gem() external view returns (address);
    function exit(address usr, uint256 wad) external;
}

interface SafeVatLike {
    function wards(address usr) external view returns (uint256);
}

interface SafeGemLike {
    function balanceOf(address usr) external view returns (uint256);
}

contract IlkRegistrySafeSpellMitigationTest is Test {
    uint256 internal constant SNAPSHOT_BLOCK = 25_694_337;
    bytes32 internal constant AAVE_A = "AAVE-A";

    address internal constant REGISTRY = 0x5a464C28D19848f44199D003BeF5ecc87d090F87;
    address internal constant PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address internal constant AAVE_JOIN = 0x24e459F61cEAa7b1cE70Dbaea938940A7c5aD46e;

    function testGovernanceCanBlockReAddByClearingPipWithoutBreakingExit() public {
        vm.createSelectFork("mainnet", SNAPSHOT_BLOCK);

        SafeRegistryLike registry = SafeRegistryLike(REGISTRY);
        SafeSpotterLike spotter = SafeSpotterLike(registry.spot());
        SafeJoinLike join = SafeJoinLike(AAVE_JOIN);
        SafeVatLike vat = SafeVatLike(registry.vat());

        assertEq(registry.join(AAVE_A), address(0), "AAVE-A unexpectedly registered");
        assertEq(join.live(), 1, "AAVE Join is not live");
        assertEq(vat.wards(AAVE_JOIN), 1, "AAVE Join is not Vat-authorized");
        assertEq(spotter.wards(PAUSE_PROXY), 1, "Pause Proxy cannot configure Spotter");

        (address pipBefore,) = spotter.ilks(AAVE_A);
        assertTrue(pipBefore != address(0), "AAVE residual pip already cleared");

        uint256 custodyBefore = SafeGemLike(join.gem()).balanceOf(AAVE_JOIN);
        assertGt(custodyBefore, 0, "AAVE Join has no custody balance");

        // A zero-amount exit exercises the Join -> Vat.slip authorization path.
        join.exit(address(this), 0);

        vm.prank(PAUSE_PROXY);
        spotter.file(AAVE_A, "pip", address(0));

        (address pipAfter,) = spotter.ilks(AAVE_A);
        assertEq(pipAfter, address(0), "governance did not clear residual pip");

        vm.expectRevert(bytes("IlkRegistry/pip-invalid"));
        registry.add(AAVE_JOIN);

        // Clearing the discovery/oracle condition does not revoke the Join's Vat ward
        // and therefore does not break collateral exit.
        assertEq(vat.wards(AAVE_JOIN), 1, "Join Vat authorization was changed");
        assertEq(join.live(), 1, "Join was caged");
        join.exit(address(this), 0);

        uint256 custodyAfter = SafeGemLike(join.gem()).balanceOf(AAVE_JOIN);

        console2.log("AAVE residual pip before", pipBefore);
        console2.log("AAVE residual pip after", pipAfter);
        console2.log("AAVE Join Vat ward after mitigation", vat.wards(AAVE_JOIN));
        console2.log("AAVE Join live after mitigation", join.live());
        console2.log("AAVE Join custody before", custodyBefore);
        console2.log("AAVE Join custody after", custodyAfter);
        console2.log("public re-add blocked", true);
        console2.log("zero-amount exit still succeeds", true);

        assertEq(custodyAfter, custodyBefore, "zero exit unexpectedly moved collateral");
    }
}
