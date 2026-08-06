# Adversarial triage analysis

## Simulated triage disposition

**Likely disposition: technically valid behavior, but reject as out of scope / intended composition unless the governance-result impact is interpreted broadly.**

The technical facts are reproducible. The main dispute is whether they constitute the listed Critical governance impact rather than an incomplete housekeeping spell operating against an intentionally public registry.

## Strongest rejection arguments

### 1. IlkRegistry is intentionally public

The official README calls it a publicly modifiable registry. `add(address)` is deliberately permissionless, and official tests exercise `removeAuth -> add` as a supported refresh lifecycle.

A triager can therefore argue that a live, Vat-authorized Join is intentionally eligible for registration and that `removeAuth` does not promise a permanent ban.

### 2. The vote and spell were not modified

The governance vote passed normally. The deployed spell executed its encoded `removeAuth` calls exactly. `DssExec.done()` only records that `cast()` was executed; it is not a postcondition checker.

Combining the legitimate cast with a later authorized public call in one transaction does not automatically turn the public call into manipulation of vote counting or spell bytecode.

### 3. Sky expressly assigns governance/permissionless composition to spells

Current program rules state that grouping specific governance actions, including permissionless actions with governance actions, is assumed to be implemented at the spell or `dss-exec-lib` layer.

A triager can say the 2025 spell should have cleared residual Spotter/Dog configuration or otherwise made the old Join fail `add()`. That is a spell-composition issue explicitly assumed by the program, not a rewarded flaw in the Registry.

### 4. Chainlog inconsistency is expressly a non-issue

Current rules state that missing, extra, wrong, or inconsistent Chainlog values are assumed non-issues. Therefore the previous “coordinated Chainlog retirement bypass” framing must not be used as the severity driver.

### 5. MCD_VAT is not a causal sink of the Registry behavior

A focused differential control proves that an arbitrary address can directly call the residual LINK oracle `poke()` and then public `MCD_SPOT.poke("LINK-A")`, producing exactly the same final `MCD_VAT.spot` value as `IlkRegistry.add -> OmegaPoker.refresh -> OmegaPoker.poke`.

Machine result:

```text
LINK-A baseline spot                         72000000000000000000000000
Direct oracle + Spotter result              145650900000000000000000000
Registry + Omega result                     145650900000000000000000000
Final values equal                          true
```

`MCD_VAT` must therefore not be selected as the primary affected asset or claimed as unique downstream impact.

### 6. Economic offboarding remains intact

For all 31 positively restorable ilks:

- `Art == 0`;
- `line == 0`;
- no residual AutoLine configuration exists;
- no LineMom entry exists;
- no active legacy Clipper auction exists;
- no Clipper Vat collateral balance exists.

The residual-Art RWA controls are not addable. No borrowing, liquidation, theft, insolvency, or fund freeze is reproduced.

A triager can characterize Registry removal as housekeeping after economic offboarding, not a security boundary.

### 7. Emergency-spell effects are finite operational grief

Re-added records make deployed multi-emergency spell `done()` checks false and require repeated execution, but:

- no funds are frozen;
- no active auction is left unprotected;
- each action fits comfortably within block gas limits;
- the target set is finite;
- the program does not list generic griefing or gas consumption among the visible accepted Sky smart-contract impacts.

This is useful corroboration of target-set mutation, but not an independent listed severity.

### 8. IlkRegistry/OmegaPoker may not be individually listed assets

The visible asset table explicitly lists core DSS contracts, Medians, and OSMs, but not IlkRegistry or OmegaPoker. The program permits consideration of any deployed Sky contract only for a demonstrated Critical impact. Without the governance-impact classification, asset scope becomes an additional rejection path.

### 9. The issue may be treated as a feature request

A governance tombstone is a clean fix, but triage may say the protocol intentionally chose Vat authorization and residual module configuration as addability conditions. Asking for a new terminal lifecycle bit can be characterized as a feature request unless the voted postcondition is accepted as a security invariant.

## What survives the rejection attempt

The following facts remain technically strong and unique to Registry mutation:

1. The official proposal said the listed ilks would be removed from IlkRegistry to finalize offboarding.
2. Clean execution produces `72 -> 30`.
3. One arbitrary address can execute the real approved spell and return from the same transaction at `61`, with 31 removed records restored.
4. The behavior remains live at block `25,694,337`, where production `add()` accepts all 31 adapters.
5. Public users cannot remove the restored entries because their Joins remain live.
6. A repeated governance-removal test proves three successful `removeAuth` cycles can be followed by four public re-additions, with the attacker controlling the final Registry and Omega target-set state.
7. `Vat.deny(join)` blocks re-add but also breaks `GemJoin.exit`; at least one affected Join holds user collateral.
8. Caging does not create a terminal block because `add()` ignores `Join.live()`.

## Final adversarial assessment

The behavior is a real lifecycle/state-machine weakness. The payout question depends almost entirely on whether Sky interprets its Critical governance impact as covering an arbitrary caller's repeatable veto over the exact on-chain postcondition approved by a vote.

The current program language about spell-level grouping is powerful counterevidence. The report should acknowledge it internally and avoid unsupported alternative impacts.
