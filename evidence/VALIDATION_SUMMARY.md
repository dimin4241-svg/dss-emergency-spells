# Sky IlkRegistry governance-removal veto — validation summary

## Executive conclusion

The production IlkRegistry cannot represent terminal governance removal of an ilk.

A real approved spell removed 42 offboarded records and produced a clean Registry count of 30. One arbitrary caller can execute that spell and restore 31 records before the same transaction returns, producing a final count of 61.

The same primitive remains live at block `25,694,337`, where production `add()` accepts all 31 adapters. A new repeated-veto test proves that even after three legitimate governance `removeAuth` cycles, four public re-additions let the arbitrary caller choose the final Registry and OmegaPoker target-set state.

Adversarial controls materially narrow the impact:

- direct public legacy-oracle `poke()` plus public `MCD_SPOT.poke()` reproduces the same `MCD_VAT.spot` result as the Registry/Omega path;
- Chainlog inconsistency is explicitly a non-issue under current Sky rules;
- no debt, ceiling, auction, fund-freeze, theft, insolvency, or permanent DoS is demonstrated.

The only surviving severity theory is repeatable veto over the exact Registry absence postcondition approved by governance.

## Root cause

`removeAuth(ilk)` deletes the current record but stores no terminal lifecycle marker.

`add(adapter)` is public and accepts an absent record when the old adapter remains technically valid:

- correct Vat;
- adapter remains a Vat ward;
- residual Spotter oracle pointer exists; and
- residual Dog/Cat liquidation pointer exists.

The contract therefore cannot distinguish:

```text
temporary absence for refresh
```

from:

```text
terminal absence after governance offboarding
```

Official tests support temporary `removeAuth -> add`, while the 2025 governance proposal used removal to finalize offboarding.

## Proof matrix

| Proof | Environment | Result |
|---|---|---|
| Real approved cleanup | block `23,118,263` | Registry `72 -> 30`; 42 records removed |
| Atomic real-spell reversal | same fork | public caller restores 31; final count 61; spell `done=true` |
| Current exact restoration | block `25,694,337` | production `add()` accepts 31/31; Registry `35 -> 66` |
| Repeated governance veto | same current fork | 3 `removeAuth` cycles, 4 public re-adds; attacker wins final Registry/Omega state |
| Persistence | current fork | public removal blocked for all 31 restored live Joins |
| Caging control | current fork | caged adapter remains repeatedly `add -> remove -> add` capable |
| Vat deny control | current fork | deny blocks add but also makes `GemJoin.exit()` revert |
| Direct oracle causality control | current fork | direct oracle+Spotter and Registry+Omega produce identical LINK-A `Vat.spot` |
| Residual debt control | current fork | residual-Art RWA adapters rejected by production `add()` |
| Automation control | current fork | no residual AutoLine or LineMom enablement |
| Auction control | current fork | no active auctions or Clipper Vat collateral balances |
| Keeper control | current fork | no paid/executable job and no block-gas DoS |

## Primary proof — atomic real-spell reversal

Test:

```text
src/IlkRegistryAtomicGovernanceReversal.t.sol
```

Result:

```text
[PASS] testOneUnprivilegedTransactionCastsSpellAndReversesCleanup()
spell done true
restored atomically 31
final Registry count 61
atomic call gas used 9,535,907
block gas limit 44,868,168
```

Clean result:

```text
72 -> 30
```

Public caller's final result:

```text
72 -> 30 -> 61
```

## Strongest current proof — repeatable governance veto

Test:

```text
src/IlkRegistryGovernanceRemovalVeto.t.sol
```

At block `25,694,337`, the test alternates legitimate Pause Proxy `removeAuth(AAVE-A)` with arbitrary public `add(AAVE_JOIN)` and refreshes deployed OmegaPoker after every transition.

Result:

```text
[PASS] testPublicCallerCanVetoRepeatedGovernanceRemovalCycles()
governance removeAuth cycles 3
successful unprivileged re-adds 4
final AAVE-A present in Registry true
final AAVE-A present in Omega true
total attacker add gas 758,204
AAVE Join remains live 1
AAVE Join remains Vat ward 1
```

Workflow run: `31092529354`.

This proves the issue is not limited to a historical spell. Existing `removeAuth` cannot establish a persistent absence postcondition while the old adapter remains addable.

## Current mass restoration

Test:

```text
src/IlkRegistryCurrentMassReAdd.t.sol
```

Result:

```text
initial Registry count 35
successful additions    31 / 31
final Registry count    66
```

All positively restored ilks have `Art == 0` and `line == 0`.

## Causality control that narrows the report

Test:

```text
src/IlkRegistryDirectSpotterSingleControl.t.sol
```

Result:

```text
[PASS] testDirectPublicOracleAndSpotterPathMatchesRegistryOmegaResult()
LINK-A baseline                         72000000000000000000000000
Direct oracle + Spotter result          145650900000000000000000000
Registry + Omega result                 145650900000000000000000000
Final values equal                      true
```

Workflow run: `31092196421`.

Therefore:

- Registry re-add is not necessary to produce the tested `MCD_VAT.spot` delta;
- `MCD_VAT` is not the primary affected asset;
- oracle/Spotter state changes are not the severity driver.

The unique Registry consequence is canonical list and list-consumer target-set membership.

## Persistence and mitigation constraints

- all 31 restored Joins remain live;
- public `remove()` is blocked for all 31;
- `add()` ignores `Join.live()`, so caging alone is not terminal;
- `Vat.deny(join)` blocks add but also breaks `GemJoin.exit()`;
- the AAVE Join held approximately `77.033778046632910564 AAVE` at the pinned state.

Governance can still work around the issue by clearing residual addability conditions or changing/deploying the Registry. Remediation is not impossible.

## Secondary operational evidence

Restored records alter deployed OmegaPoker and multi-emergency target sets. They can make completed emergency `done()` checks false and require finite repeated execution.

These results prove Registry membership is consumed on-chain, but they are not independent listed impacts and are not used to claim fund loss or DoS.

## Strongest counterevidence

Current Sky rules state:

- governance actions and relevant permissionless actions are assumed to be grouped at the spell or `dss-exec-lib` layer;
- inconsistent Chainlog values are assumed non-issues;
- only explicitly listed impacts are accepted.

A triager may therefore classify the 2025 result as incomplete spell composition against an intentionally public Registry. This is the principal rejection risk.

## Explicitly excluded claims

Do not claim:

- unique `MCD_VAT` impact;
- Chainlog bypass as a rewarded impact;
- debt reopening;
- residual-Art RWA restoration;
- active auction exposure;
- automatic debt-ceiling reopening;
- theft, insolvency, liquidation, or fund freeze;
- keeper payout extraction;
- permanent or block-gas DoS;
- historical `remove -> removeAuth` race; or
- alternate-gem Join substitution.

## Recommended remediation

Introduce a governance-controlled terminal lifecycle state, or ensure terminal offboarding spells clear the residual conditions that make old adapters addable.

A tombstone design preserves technical refresh while making terminal removal explicit:

```solidity
mapping(bytes32 => bool) public blocked;

function blockIlk(bytes32 ilk) external auth {
    blocked[ilk] = true;
    if (ilkData[ilk].join != address(0)) _remove(ilk);
}

function add(address adapter) external {
    bytes32 ilk = JoinLike(adapter).ilk();
    require(!blocked[ilk], "IlkRegistry/ilk-blocked");
    // existing validation
}
```
