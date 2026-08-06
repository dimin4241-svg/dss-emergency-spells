// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {console2} from "forge-std/console2.sol";
import {IlkRegistryCurrentMassReAddTest} from "./IlkRegistryCurrentMassReAdd.t.sol";

interface AutomationChainlogLike {
    function getAddress(bytes32 key) external view returns (address);
}

interface AutomationAutoLineLike {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc);
}

interface AutomationLineMomLike {
    function ilks(bytes32 ilk) external view returns (uint256);
}

contract IlkRegistryResidualAutomationScanTest is IlkRegistryCurrentMassReAddTest {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function _chainlog(bytes32 key) internal view returns (address) {
        return AutomationChainlogLike(CHAINLOG).getAddress(key);
    }

    function testScanRemovedIlksForResidualDebtCeilingAutomation() public {
        vm.createSelectFork("mainnet", SNAPSHOT_BLOCK);
        AutomationAutoLineLike autoLine = AutomationAutoLineLike(_chainlog("MCD_IAM_AUTO_LINE"));
        AutomationLineMomLike lineMom = AutomationLineMomLike(_chainlog("LINE_MOM"));
        bytes32[] memory targets = _targets();

        uint256 autoLineEnabled;
        uint256 lineMomEnabled;

        for (uint256 i = 0; i < targets.length; i++) {
            (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc) = autoLine.ilks(targets[i]);
            uint256 lineMomFlag = lineMom.ilks(targets[i]);

            if (maxLine != 0 || gap != 0 || ttl != 0 || last != 0 || lastInc != 0) {
                autoLineEnabled++;
                console2.log("residual AutoLine ilk");
                console2.logBytes32(targets[i]);
                console2.log("maxLine", maxLine);
                console2.log("gap", gap);
                console2.log("ttl", ttl);
                console2.log("last", last);
                console2.log("lastInc", lastInc);
            }

            if (lineMomFlag != 0) {
                lineMomEnabled++;
                console2.log("residual LineMom ilk");
                console2.logBytes32(targets[i]);
                console2.log("LineMom flag", lineMomFlag);
            }
        }

        console2.log("removed ilks with residual AutoLine config", autoLineEnabled);
        console2.log("removed ilks enabled in LineMom", lineMomEnabled);
    }
}
