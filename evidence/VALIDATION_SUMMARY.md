# Sky IlkRegistry governance-retirement bypass — validation summary

## Executive conclusion

The production IlkRegistry at `0x5a464C28D19848f44199D003BeF5ecc87d090F87` cannot represent terminal collateral offboarding.

Governance used two coordinated controls in the August 7, 2025 spell:

1. remove legacy oracle keys from Chainlog; and
2. remove the associated offboarded ilks from IlkRegistry to finalize offboarding.

Permissionless `IlkRegistry.add(address)` defeats that combined result. It reconstructs removed records from legacy Join adapters and residual `MCD_SPOT` configuration without consulting Chainlog or any governance lifecycle marker.

The strongest machine proof executes the complete chain in one unprivileged external call:

```text
real approved spell.cast()
-> 31 permissionless Registry additions
-> deployed OmegaPoker.refresh()
-> deployed OmegaPoker.poke()
```

Before the call returns:

```text
spell.done()                              true
selected Chainlog oracle keys absent         8
Registry records restored                   31
selected retired paths recached               7
selected retired MCD_VAT.spot values changed  2
final Registry count                         61
call gas used                         13,401,327
block gas limit                       44,868,168
```

The current deployment independently retains the same primitive. At block `25,694,337`, one public call with no historical spell restores 31 records, recaches 26 retired paths, and changes 15 `MCD_VAT.spot` values.

No theft, borrowing, liquidation, debt reopening, active-auction loss, insolvency, or block-gas DoS is claimed.

## Root cause

`add(address)` accepts a missing standard collateral record when:

- the Join points to production Vat;
- the Join remains a Vat ward;
- the ilk is absent from Registry;
- residual Spotter `pip` is non-zero; and
- a residual Dog clip or Cat flip exists.

It stores no distinction between:

```text
temporary absence for technical refresh
```

and:

```text
terminal absence after governance offboarding
```

It also obtains `pip` from Spotter, so Chainlog retirement does not prevent reconstruction.

## Proof matrix

| Evidence | Environment | Result |
|---|---|---|
| Real approved spell cleanup | block `23,118,263` | clean Registry `72 -> 30`, 42 removals |
| Atomic cleanup reversal | same historical fork | one public call restores 31; final count 61; `done=true` |
| Atomic oracle-retirement bypass | same historical fork | Chainlog keys remain absent; 7 retired paths recached; 2 `MCD_VAT.spot` changes |
| Current one-call propagation | block `25,694,337` | Registry `35 -> 66`; 26 recached; 15 Vat spot changes |
| Exact current addability | same current fork | production `add()` accepts 31/31 adapters |
| Persistence | same current fork | public removal blocked for 31/31 restored live entries |
| Emergency completion reopening | same current fork | 25 OSM and 30 Clip obligations; both deployed spells return to `done=false` |
| Staged emergency grief | same current fork | 25 and 30 repeated emergency response cycles |
| Keeper differential | current fork | measurable gas increase; no new executable/paid job; no block-gas DoS |

## Primary historical one-call proof

Test:

```text
src/IlkRegistryAtomicOracleRetirementProof.t.sol
```

Result:

```text
[PASS] testOneExternalCallReactivatesRetiredOraclePathIntoVat()
approved spell done true
Chainlog keys still retired 8
Registry ilks restored in same call 31
retired ilks recached in same call 7
retired Vat.spot values changed in same call 2
final Registry count 61
end-to-end call gas used 13,401,327
block gas limit 44,868,168
```

Workflow run: `31087775218`.

The two selected spot deltas were:

```text
LINK-A
72,000,000,000,000,000,000,000,000
-> 145,650,900,000,000,000,000,000,000

RENBTC-A
860,343,300,000,000,000,000,000,000,000
-> 2,397,198,400,000,000,000,000,000,000,000
```

The selected Chainlog keys remain absent. The bypass uses residual Spotter state as an alternate reconstruction source.

## Current one-call proof

Test:

```text
src/IlkRegistryCurrentAtomicVatPropagation.t.sol
```

Result:

```text
[PASS] testCurrentOneExternalCallRestoresLegacyPathsAndChangesVat()
current Registry baseline 35
current one-call restored ilks 31
current final Registry count 66
current retired ilks recached 26
current retired Vat.spot values changed 15
current one-call gas used 11,175,460
block gas limit 60,000,000
```

Workflow run: `31088226922`, final successful attempt.

The 15 changed ilks were:

- `CRVV1ETHSTETH-A`
- `GNO-A`
- `KNC-A`
- `LINK-A`
- `RENBTC-A`
- `UNIV2AAVEETH-A`
- `UNIV2DAIETH-A`
- `UNIV2DAIUSDT-A`
- `UNIV2ETHUSDT-A`
- `UNIV2LINKETH-A`
- `UNIV2UNIETH-A`
- `UNIV2USDCETH-A`
- `UNIV2WBTCDAI-A`
- `UNIV2WBTCETH-A`
- `USDT-A`

All positively restored ilks retain `Art == 0` and `line == 0`.

## Differential coordinated-retirement control

Test:

```text
src/IlkRegistryChainlogRetirementBypass.t.sol
```

Clean state:

```text
selected Chainlog keys retired 8
selected retired ilks cached by Omega 0
Registry count 30
```

Attacked state:

```text
selected Chainlog keys still retired 8
Registry records restored 31
selected retired ilks cached 7
selected retired Vat.spot changes 2
Registry count 61
```

Workflow run: `31086708376`.

## Deployed emergency-spell consequences

Tests:

```text
src/IlkRegistryEmergencySpellImpact.t.sol
src/IlkRegistryEmergencyReexecutionGrief.t.sol
```

Production contracts:

```text
MultiOsmStopSpell      0x3021dEdB0bC677F43A23Fcd1dE91A07e5195BaE8
MultiClipBreakerSpell  0x828824dBC62Fba126C76E0Abe79AE28E5393C2cb
```

After a legitimate clean emergency execution reaches `done == true`, restoring the retired records causes:

```text
MultiOsmStopSpell:
new pending obligations 25
done after restoration  false
re-execution gas         1,100,041

MultiClipBreakerSpell:
new pending obligations 30
done after restoration  false
re-execution gas         2,637,142
```

Staged one-at-a-time additions force:

```text
25 repeated MultiOsmStop executions
30 repeated MultiClipBreaker executions
```

Measured total repeated response gas:

```text
OSM  12,279,717
Clip 26,663,517
```

Workflow runs: `31086518004` and `31088034426`.

These results are presented as confirmed incident-response grief and mutable completion. They are not presented as theft, permanent DoS, or block-gas DoS.

## Persistence and mitigation constraints

- all 31 restored Joins remain `live == 1`;
- public `remove()` fails for all 31;
- caging does not terminally block re-add because `add()` ignores `Join.live()`;
- `Vat.deny(join)` blocks re-add but also causes `GemJoin.exit()` to revert;
- the AAVE Join held approximately `77.033778046632910564 AAVE` at the pinned block.

A new governance action can repair the state. The original terminal action did not create a terminal state.

## Counterevidence and excluded claims

The following were tested and must not be claimed:

| Theory | Result |
|---|---|
| Residual-debt RWA restoration | `RWA012-A` and `RWA013-A` revert with `invalid-auction-contract` |
| Automatic debt-ceiling reopening | residual AutoLine config 0; LineMom enabled count 0 |
| Legacy auction funds | active auction count 0; Clipper `Vat.gem` balance 0 |
| Current swap-and-pop mutation | publicly removable current Registry entries 0 |
| Historical `remove -> removeAuth` race | none of the 2025 spell targets was publicly removable pre-cast |
| Malicious alternate Join/gem substitution | no qualifying second historical Join established |
| Paid keeper work | no keeper became executable; no payout path |
| Block-gas DoS | all measured primary and emergency executions fit the block limit |
| Borrowing/liquidation/theft/insolvency | not demonstrated |

Negative-control workflow runs:

- current public-removal scan: `31087074419`
- residual automation scan: `31087315028`
- legacy auction scan: `31087623400`
- keeper bounded impact: `31080500141`

## Recommended remediation

A `Join.live()` check alone is insufficient because the currently affected adapters are live to preserve exit.

Add a governance-controlled terminal lifecycle state:

```solidity
mapping(bytes32 => bool) public blocked;

function blockIlk(bytes32 ilk) external auth {
    blocked[ilk] = true;
    if (ilkData[ilk].class != 0) _remove(ilk);
}

function unblockIlk(bytes32 ilk) external auth {
    blocked[ilk] = false;
}

function add(address adapter) external {
    bytes32 ilk = JoinLike(adapter).ilk();
    require(!blocked[ilk], "IlkRegistry/ilk-blocked");
    // existing technical validation
}
```

Terminal offboarding should set the block in the same spell that retires Chainlog keys and removes the Registry record.

Also:

- harden `_remove` with existence and array/mapping consistency checks;
- define explicit caged-adapter behavior; and
- make list-consuming emergency logic use a governance-stable or lifecycle-aware target set.
