// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

interface IlkRegistryLike {
    function vat() external view returns (address);
    function spot() external view returns (address);
    function dog() external view returns (address);
    function cat() external view returns (address);
    function wards(address) external view returns (uint256);
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function join(bytes32) external view returns (address);
    function pip(bytes32) external view returns (address);
    function xlip(bytes32) external view returns (address);
    function class(bytes32) external view returns (uint256);
    function add(address) external;
    function remove(bytes32) external;
    function removeAuth(bytes32) external;
}

interface JoinLike {
    function vat() external view returns (address);
    function ilk() external view returns (bytes32);
    function gem() external view returns (address);
    function dec() external view returns (uint256);
    function live() external view returns (uint256);
}

interface VatLike {
    function wards(address) external view returns (uint256);
    function ilks(bytes32) external view returns (
        uint256 Art,
        uint256 rate,
        uint256 spot,
        uint256 line,
        uint256 dust
    );
}

interface SpotLike {
    function ilks(bytes32) external view returns (address pip, uint256 mat);
}

interface DogLike {
    function ilks(bytes32) external view returns (address clip, uint256 chop, uint256 hole, uint256 dirt);
}

interface CatLike {
    function ilks(bytes32) external view returns (address flip, uint256 chop, uint256 dunk);
}

contract IlkRegistryReAddTest is Test {
    uint256 internal constant FORK_BLOCK = 23_118_263;

    address internal constant REGISTRY = 0x5a464C28D19848f44199D003BeF5ecc87d090F87;
    address internal constant AAVE_JOIN = 0x24e459F61cEAa7b1cE70Dbaea938940A7c5aD46e;
    address internal constant PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26affef007E98FB;

    bytes32 internal constant AAVE_A = "AAVE-A";
    bytes32 internal constant ETH_A = "ETH-A";

    address internal attacker = address(0xBEEF);
    address internal stranger = address(0xCAFE);

    IlkRegistryLike internal registry = IlkRegistryLike(REGISTRY);
    VatLike internal vat;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        vat = VatLike(registry.vat());
    }

    function testPermissionlessReAddAcceptsCagedOffboardedAaveJoin() public {
        JoinLike join = JoinLike(AAVE_JOIN);

        assertEq(registry.join(AAVE_A), address(0), "AAVE-A must start absent from registry");
        assertEq(join.vat(), address(vat), "legacy join still points at production Vat");
        assertEq(join.ilk(), AAVE_A, "legacy join still reports AAVE-A");
        assertEq(join.live(), 0, "legacy join is caged");
        assertEq(vat.wards(AAVE_JOIN), 1, "legacy join remains a Vat ward");

        (address spotPip,) = SpotLike(registry.spot()).ilks(AAVE_A);
        (address clip,,,) = DogLike(registry.dog()).ilks(AAVE_A);
        (address flip,,) = CatLike(registry.cat()).ilks(AAVE_A);
        assertTrue(spotPip != address(0), "Spotter still has a price feed");
        assertTrue(clip != address(0) || flip != address(0), "liquidation module still has an auction address");

        uint256 beforeCount = registry.count();

        vm.prank(attacker);
        registry.add(AAVE_JOIN);

        assertEq(registry.count(), beforeCount + 1, "unprivileged caller appended the removed ilk");
        assertEq(registry.join(AAVE_A), AAVE_JOIN, "registry now trusts the caged join");
        assertEq(registry.pip(AAVE_A), spotPip, "registry copied the residual Spotter pip");
        assertTrue(registry.xlip(AAVE_A) != address(0), "registry copied a residual auction address");
        assertTrue(registry.class(AAVE_A) == 1 || registry.class(AAVE_A) == 2, "registry assigned a standard class");
        assertEq(JoinLike(registry.join(AAVE_A)).live(), 0, "registered join remains unusable/caged");

        bytes32[] memory listed = registry.list();
        bool found;
        for (uint256 i = 0; i < listed.length; i++) {
            if (listed[i] == AAVE_A) found = true;
        }
        assertTrue(found, "all list-based consumers now receive AAVE-A");
    }

    function testAnyoneCanToggleRemovedIlkBackIntoRegistryIndefinitely() public {
        uint256 originalCount = registry.count();

        vm.prank(attacker);
        registry.add(AAVE_JOIN);
        assertEq(registry.count(), originalCount + 1);

        vm.prank(stranger);
        registry.remove(AAVE_A);
        assertEq(registry.count(), originalCount);
        assertEq(registry.join(AAVE_A), address(0));

        vm.prank(attacker);
        registry.add(AAVE_JOIN);
        assertEq(registry.count(), originalCount + 1);
        assertEq(registry.join(AAVE_A), AAVE_JOIN);
    }

    function testAuthorizedRegistryRemovalOfLiveIlkIsImmediatelyUndoableByAnyone() public {
        address ethJoin = registry.join(ETH_A);
        assertTrue(ethJoin != address(0), "ETH-A must start registered");
        assertEq(JoinLike(ethJoin).live(), 1, "ETH-A join must be live");
        assertEq(registry.wards(PAUSE_PROXY), 1, "Pause Proxy must be a registry ward");

        vm.prank(PAUSE_PROXY);
        registry.removeAuth(ETH_A);
        assertEq(registry.join(ETH_A), address(0), "authorized removal succeeded");

        vm.prank(attacker);
        registry.add(ethJoin);
        assertEq(registry.join(ETH_A), ethJoin, "unprivileged caller reversed the authorized removal");
    }

    function testReAddDoesNotReopenDebtButDoesPolluteAuthoritativeMetadata() public {
        (uint256 Art,,, uint256 line,) = vat.ilks(AAVE_A);
        assertEq(Art, 0, "AAVE-A has no normalized debt at the fork block");
        assertEq(line, 0, "AAVE-A has no debt ceiling at the fork block");

        vm.prank(attacker);
        registry.add(AAVE_JOIN);

        (uint256 ArtAfter,,, uint256 lineAfter,) = vat.ilks(AAVE_A);
        assertEq(ArtAfter, Art, "Registry.add does not mutate Vat debt");
        assertEq(lineAfter, line, "Registry.add does not mutate Vat line");
        assertEq(registry.join(AAVE_A), AAVE_JOIN, "metadata pollution still occurred");
    }
}
