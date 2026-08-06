// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

interface CurrentRegistryLike {
    function vat() external view returns (address);
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function join(bytes32) external view returns (address);
    function pip(bytes32) external view returns (address);
    function xlip(bytes32) external view returns (address);
    function add(address) external;
}

interface CurrentJoinLike {
    function live() external view returns (uint256);
    function vat() external view returns (address);
    function ilk() external view returns (bytes32);
    function gem() external view returns (address);
}

interface CurrentVatLike {
    function wards(address) external view returns (uint256);
    function ilks(bytes32) external view returns (uint256 Art, uint256 rate, uint256 spot, uint256 line, uint256 dust);
}

contract IlkRegistryCurrentMassReAddTest is Test {
    uint256 internal constant SNAPSHOT_BLOCK = 25_694_337;
    address internal constant REGISTRY = 0x5a464C28D19848f44199D003BeF5ecc87d090F87;
    address internal constant RWA012_JOIN = 0x75646f68B8C5D8f415891F7204978eFb81Ec6410;
    address internal constant RWA013_JOIN = 0x779D0fD012815D4239BAf75140E6B2971bEd5113;

    CurrentRegistryLike internal constant registry = CurrentRegistryLike(REGISTRY);

    function _targets() internal pure returns (bytes32[] memory t) {
        t = new bytes32[](31);
        t[0] = "AAVE-A";
        t[1] = "BAL-A";
        t[2] = "BAT-A";
        t[3] = "COMP-A";
        t[4] = "CRVV1ETHSTETH-A";
        t[5] = "GNO-A";
        t[6] = "GUSD-A";
        t[7] = "KNC-A";
        t[8] = "LINK-A";
        t[9] = "LRC-A";
        t[10] = "MANA-A";
        t[11] = "MATIC-A";
        t[12] = "PAXUSD-A";
        t[13] = "RENBTC-A";
        t[14] = "RETH-A";
        t[15] = "TUSD-A";
        t[16] = "UNI-A";
        t[17] = "UNIV2AAVEETH-A";
        t[18] = "UNIV2DAIETH-A";
        t[19] = "UNIV2DAIUSDT-A";
        t[20] = "UNIV2ETHUSDT-A";
        t[21] = "UNIV2LINKETH-A";
        t[22] = "UNIV2UNIETH-A";
        t[23] = "UNIV2USDCETH-A";
        t[24] = "UNIV2WBTCDAI-A";
        t[25] = "UNIV2WBTCETH-A";
        t[26] = "USDC-A";
        t[27] = "USDC-B";
        t[28] = "USDT-A";
        t[29] = "YFI-A";
        t[30] = "ZRX-A";
    }

    function _adapters() internal pure returns (address[] memory a) {
        a = new address[](31);
        a[0] = 0x24e459F61cEAa7b1cE70Dbaea938940A7c5aD46e;
        a[1] = 0x4a03Aa7fb3973d8f0221B466EefB53D0aC195f55;
        a[2] = 0x3D0B1912B66114d4096F48A8CEe3A56C231772cA;
        a[3] = 0xBEa7cDfB4b49EC154Ae1c0D731E4DC773A3265aA;
        a[4] = 0x82D8bfDB61404C796385f251654F6d7e92092b5D;
        a[5] = 0x7bD3f01e24E0f0838788bC8f573CEA43A80CaBB5;
        a[6] = 0xe29A14bcDeA40d83675aa43B72dF07f649738C8b;
        a[7] = 0x475F1a89C1ED844A08E8f6C50A00228b5E59E4A9;
        a[8] = 0xdFccAf8fDbD2F4805C174f856a317765B49E4a50;
        a[9] = 0x6C186404A7A238D3d6027C0299D1822c1cf5d8f1;
        a[10] = 0xA6EA3b9C04b8a38Ff5e224E7c3D6937ca44C0ef9;
        a[11] = 0x885f16e177d45fC9e7C87e1DA9fd47A9cfcE8E13;
        a[12] = 0x7e62B7E279DFC78DEB656E34D6a435cC08a44666;
        a[13] = 0xFD5608515A47C37afbA68960c1916b79af9491D0;
        a[14] = 0xC6424e862f1462281B0a5FAc078e4b63006bDEBF;
        a[15] = 0x4454aF7C8bb9463203b66C816220D41ED7837f44;
        a[16] = 0x3BC3A58b4FC1CbE7e98bB4aB7c99535e8bA9b8F1;
        a[17] = 0x42AFd448Df7d96291551f1eFE1A590101afB1DfF;
        a[18] = 0x2502F65D77cA13f183850b5f9272270454094A08;
        a[19] = 0xAf034D882169328CAf43b823a4083dABC7EEE0F4;
        a[20] = 0x4aAD139a88D2dd5e7410b408593208523a3a891d;
        a[21] = 0xDae88bDe1FB38cF39B6A02b595930A3449e593A6;
        a[22] = 0xf11a98339FE1CdE648e8D1463310CE3ccC3d7cC1;
        a[23] = 0x03Ae53B33FeeAc1222C3f372f32D37Ba95f0F099;
        a[24] = 0xD40798267795Cbf3aeEA8E9F8DCbdBA9b5281fcC;
        a[25] = 0xDc26C9b7a8fe4F5dF648E314eC3E6Dc3694e6Dd2;
        a[26] = 0xA191e578a6736167326d05c119CE0c90849E84B7;
        a[27] = 0x2600004fd1585f7270756DDc88aD9cfA10dD0428;
        a[28] = 0x0Ac6A1D74E84C2dF9063bDDc31699FF2a2BB22A2;
        a[29] = 0x3ff33d9162aD47660083D7DC4bC02Fb231c81677;
        a[30] = 0xc7e8Cd72BDEe38865b4F5615956eF47ce1a7e5D0;
    }

    function _contains(bytes32 needle) internal view returns (bool) {
        bytes32[] memory values = registry.list();
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] == needle) return true;
        }
        return false;
    }

    function testCurrentMainnetOneTransactionRestoresExactly31RemovedIlks() public {
        vm.createSelectFork("mainnet", SNAPSHOT_BLOCK);

        bytes32[] memory targets = _targets();
        address[] memory adapters = _adapters();
        CurrentVatLike vat = CurrentVatLike(registry.vat());

        uint256 initialCount = registry.count();
        uint256 gasBefore = gasleft();
        uint256 nonzeroArtOrLine;

        console2.log("fork block", block.number);
        console2.log("initial registry count", initialCount);
        assertEq(initialCount, 35, "unexpected pinned Registry baseline");

        for (uint256 i = 0; i < targets.length; i++) {
            assertEq(registry.join(targets[i]), address(0), "target already present at pinned block");
            assertEq(CurrentJoinLike(adapters[i]).vat(), address(vat), "adapter points to a different Vat");
            assertEq(CurrentJoinLike(adapters[i]).ilk(), targets[i], "adapter reports a different ilk");
            assertEq(CurrentJoinLike(adapters[i]).live(), 1, "adapter is not live");
            assertEq(vat.wards(adapters[i]), 1, "adapter is no longer a Vat ward");

            registry.add(adapters[i]);

            (uint256 Art,,, uint256 line,) = vat.ilks(targets[i]);
            if (Art != 0 || line != 0) nonzeroArtOrLine++;

            assertEq(registry.join(targets[i]), adapters[i], "old adapter was not restored");
            assertTrue(registry.pip(targets[i]) != address(0), "restored entry has no oracle");
            assertTrue(registry.xlip(targets[i]) != address(0), "restored entry has no auction contract");
            assertTrue(_contains(targets[i]), "restored entry is absent from list");
        }

        uint256 gasUsed = gasBefore - gasleft();
        console2.log("restored in one transaction", targets.length);
        console2.log("post-attack registry count", registry.count());
        console2.log("gas used by test body", gasUsed);
        console2.log("restored with nonzero Art or line", nonzeroArtOrLine);

        assertEq(targets.length, 31, "unexpected target set length");
        assertEq(registry.count(), 66, "all 31 legacy ilks were not restored");
        assertEq(nonzeroArtOrLine, 0, "restoration unexpectedly touched a live debt position or ceiling");
        assertLt(gasUsed, block.gaslimit, "mass restoration cannot fit in one Ethereum block");
    }

    function testRwaAdaptersWithResidualArtAreNotPermissionlesslyAddable() public {
        vm.createSelectFork("mainnet", SNAPSHOT_BLOCK);
        CurrentVatLike vat = CurrentVatLike(registry.vat());

        (uint256 rwa012Art,,, uint256 rwa012Line,) = vat.ilks("RWA012-A");
        (uint256 rwa013Art,,, uint256 rwa013Line,) = vat.ilks("RWA013-A");
        console2.log("RWA012 Art", rwa012Art);
        console2.log("RWA012 line", rwa012Line);
        console2.log("RWA013 Art", rwa013Art);
        console2.log("RWA013 line", rwa013Line);

        assertGt(rwa012Art, 0, "RWA012 has no residual Art at pinned block");
        assertGt(rwa013Art, 0, "RWA013 has no residual Art at pinned block");
        assertEq(registry.join("RWA012-A"), address(0), "RWA012 unexpectedly registered");
        assertEq(registry.join("RWA013-A"), address(0), "RWA013 unexpectedly registered");

        vm.expectRevert(bytes("IlkRegistry/invalid-auction-contract"));
        registry.add(RWA012_JOIN);

        vm.expectRevert(bytes("IlkRegistry/invalid-auction-contract"));
        registry.add(RWA013_JOIN);
    }
}
