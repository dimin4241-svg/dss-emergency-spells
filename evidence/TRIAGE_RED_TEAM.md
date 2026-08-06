# Adversarial triage analysis

## Simulated triage disposition

**Likely disposition: reject as intended public Registry behavior / incomplete spell composition / non-listed impact.**

The technical facts are reproducible, but the current Sky rules and the safe mitigation control give triage a strong program-specific rejection that the surviving governance-veto theory does not fully overcome.

## Strongest rejection arguments

### 1. IlkRegistry is intentionally public

The official README calls it a publicly modifiable registry. `add(address)` is deliberately permissionless, and official tests exercise `removeAuth -> add` as a supported refresh lifecycle.

A triager can therefore argue that a live, Vat-authorized Join with valid residual module configuration is intentionally eligible for registration and that `removeAuth` does not itself promise a permanent ban.

### 2. The vote and spell were not modified

The governance vote passed normally. The deployed spell executed its encoded `removeAuth` calls exactly. `DssExec.done()` only records that `cast()` was executed; it is not a postcondition checker.

Combining the legitimate cast with another authorized public call in one transaction does not automatically turn the public call into manipulation of vote counting, the winning option, or spell bytecode.

### 3. Sky expressly assigns governance/permissionless composition to spells

Current program rules state that grouping specific governance actions, including permissionless actions with governance actions, is assumed to be implemented at the spell or `dss-exec-lib` layer.

This maps directly onto the report: if governance wants `removeAuth` to remain final, the spell must also make the old adapter fail public `add()`.

### 4. A safe one-line spell mitigation exists and preserves collateral exit

A mainnet-fork control proves the spell could clear the residual Spotter `pip` while leaving the Join live and Vat-authorized:

```text
[PASS] testGovernanceCanBlockReAddByClearingPipWithoutBreakingExit()
AAVE residual pip before                 0x8Df8f06DC2dE0434db40dcBb32a82A104218754c
AAVE residual pip after                  0x0000000000000000000000000000000000000000
AAVE Join Vat ward after mitigation      1
AAVE Join live after mitigation          1
AAVE Join custody before                 77033778046632910564
AAVE Join custody after                  77033778046632910564
public re-add blocked                     true
zero-amount exit still succeeds           true
```

Workflow run: `31093768541`.

This defeats the argument that governance needs a new Registry tombstone or must choose between preventing re-add and preserving `GemJoin.exit`. The 2025 spell could have bundled a safe existing privileged action, exactly as the bounty rules assume.

### 5. Chainlog inconsistency is expressly a non-issue

Current rules state that missing, extra, wrong, or inconsistent Chainlog values are assumed non-issues. The earlier coordinated-Chainlog-retirement framing is not a valid severity driver.

### 6. MCD_VAT is not a causal sink of the Registry behavior

A focused differential control proves that an arbitrary address can directly call the residual LINK oracle `poke()` and then public `MCD_SPOT.poke("LINK-A")`, producing exactly the same final `MCD_VAT.spot` value as `IlkRegistry.add -> OmegaPoker.refresh -> OmegaPoker.poke`.

```text
LINK-A baseline                         72000000000000000000000000
direct oracle + Spotter result          145650900000000000000000000
Registry + Omega result                 145650900000000000000000000
final values equal                      true
```

`MCD_VAT` must not be selected as the primary affected asset or claimed as unique downstream impact.

### 7. Economic offboarding remains intact

For all 31 positively restorable ilks:

- `Art == 0`;
- `line == 0`;
- no residual AutoLine configuration exists;
- no LineMom entry exists;
- no active legacy Clipper auction exists;
- no Clipper Vat collateral balance exists.

The residual-Art RWA controls are not addable. No borrowing, liquidation, theft, insolvency, or fund freeze is reproduced.

A triager can characterize Registry removal as housekeeping after economic offboarding, not a security boundary.

### 8. Emergency-spell effects are finite operational behavior

Re-added records alter dynamic emergency target sets and `done()` checks, but no funds are frozen, no active auction is exposed, every call fits the block limit, and the target set is finite. Generic gas or operational grief is not a visible accepted Sky impact.

### 9. IlkRegistry/OmegaPoker may not be individually listed assets

The program allows consideration of a Critical impact on any deployed Sky contract, but without acceptance of the Critical governance impact there is no reliable asset or severity fallback.

### 10. The issue may be treated as a feature request

A tombstone is an architectural improvement, but the existing protocol already exposes a spell-level method to prevent re-add safely by clearing `pip` or another addability condition. Triage can reasonably characterize a permanent Registry lifecycle bit as a feature request rather than a required security fix.

## What survives the rejection attempt

The following facts remain technically valid:

1. The official proposal said the listed ilks would be removed from IlkRegistry to finalize offboarding.
2. Clean execution produces `72 -> 30`.
3. One arbitrary address can execute the real approved spell and return from the same transaction at `61`, with 31 removed records restored.
4. Production `add()` still accepts all 31 adapters at block `25,694,337`.
5. Public users cannot remove the restored entries because their Joins remain live.
6. Three governance `removeAuth` cycles can be followed by four public re-additions, with the arbitrary caller choosing the final Registry/Omega membership state.
7. The direct public re-add cost in that proof is only `758,204` total gas.

These facts prove a lifecycle/correctness weakness and a repeatable public veto over a cleanup-only `removeAuth` postcondition.

## Why the surviving proof likely still loses triage

The same evidence also shows the veto exists only while governance leaves the documented `add()` preconditions intact. A safe spell can remove one precondition without revoking Join authorization or breaking exit. Current Sky rules explicitly assign that composition to the spell layer.

Therefore the most likely triage conclusion is:

> The Registry behaves as designed; the historical housekeeping spell omitted an available companion action, and the bounty rules assume such companion actions are bundled at the spell level. No listed financial, freezing, insolvency, or governance-vote-result impact is demonstrated.

## Final adversarial assessment

The behavior is technically real but is unlikely to be rewardable under the current program. A narrow submission remains possible only by asking Sky to interpret “governance voting result” as an indefinitely enforceable Registry postcondition. The safe mitigation control makes that interpretation substantially less likely.
