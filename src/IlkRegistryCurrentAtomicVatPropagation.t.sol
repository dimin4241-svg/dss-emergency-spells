// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {console2} from "forge-std/console2.sol";
import {
    IlkRegistryOmegaPokerImpactTest,
    OmegaPokerLike
} from "./IlkRegistryOmegaPokerImpact.t.sol";
import {CurrentVatLike} from "./IlkRegistryCurrentMassReAdd.t.sol";

contract CurrentAtomicRegistryPropagation {
    function execute(address registry, address[] calldata adapters, address omega)
        external
        returns (uint256 restored)
    {
        for (uint256 i = 0; i < adapters.length; i++) {
            (bool ok,) = registry.call(abi.encodeWithSignature("add(address)", adapters[i]));
            if (ok) restored++;
        }
        OmegaPokerLike(omega).refresh();
        OmegaPokerLike(omega).poke();
    }
}

contract IlkRegistryCurrentAtomicVatPropagationTest is IlkRegistryOmegaPokerImpactTest {
    function testCurrentOneExternalCallRestoresLegacyPathsAndChangesVat() public {
        vm.createSelectFork("mainnet", SNAPSHOT_BLOCK);

        bytes32[] memory targets = _targets();
        address[] memory adapters = _adapters();
        uint256[] memory spotsBefore = new uint256[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            (,, spotsBefore[i],,) = CurrentVatLike(registry.vat()).ilks(targets[i]);
        }

        CurrentAtomicRegistryPropagation proof = new CurrentAtomicRegistryPropagation();
        uint256 gasBefore = gasleft();
        uint256 restored = proof.execute(REGISTRY, adapters, OMEGA_POKER);
        uint256 gasUsed = gasBefore - gasleft();

        uint256 changed;
        uint256 recached;
        OmegaPokerLike omega = OmegaPokerLike(OMEGA_POKER);
        for (uint256 i = 0; i < targets.length; i++) {
            if (_containsOmegaIlk(omega, targets[i])) recached++;
            (,, uint256 spotAfter,,) = CurrentVatLike(registry.vat()).ilks(targets[i]);
            if (spotAfter != spotsBefore[i]) {
                changed++;
                console2.log("current one-call Vat.spot delta");
                console2.logBytes32(targets[i]);
                console2.log("spot before", spotsBefore[i]);
                console2.log("spot after", spotAfter);
            }
        }

        console2.log("current Registry baseline", uint256(35));
        console2.log("current one-call restored ilks", restored);
        console2.log("current final Registry count", registry.count());
        console2.log("current retired ilks recached", recached);
        console2.log("current retired Vat.spot values changed", changed);
        console2.log("current one-call gas used", gasUsed);
        console2.log("block gas limit", block.gaslimit);

        assertEq(restored, 31, "unexpected current restoration count");
        assertEq(registry.count(), 66, "unexpected current final Registry count");
        assertEq(recached, 26, "unexpected current Omega legacy cache count");
        assertEq(changed, 15, "unexpected current Vat.spot delta count");
        assertLt(gasUsed, block.gaslimit, "current one-call propagation exceeds block gas limit");
    }
}
